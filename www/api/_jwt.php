<?php
// Dependency-free JWT / JWKS helpers for Sign in with Apple (apple.php,
// delete-account.php). Apple publishes no tokeninfo endpoint like Google's, so
// the identity token's RS256 signature is checked here against Apple's JWKS,
// and the client secret Apple's token endpoints require is an ES256 JWT we
// sign ourselves with the .p8 key from the developer portal.
//
// Nothing here logs a token or a key; failures are logged by reason only.
defined('NEON_API') or exit;

// --- base64url / JWT parsing ------------------------------------------------

function jwt_b64url_encode(string $bytes): string
{
    return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
}

function jwt_b64url_decode(string $s): ?string
{
    $s = strtr($s, '-_', '+/');
    $pad = strlen($s) % 4;
    if ($pad === 1) {
        return null;
    }
    if ($pad) {
        $s .= str_repeat('=', 4 - $pad);
    }
    $out = base64_decode($s, true);
    return $out === false ? null : $out;
}

// [header array, payload array, signature bytes, signing input "h.p"], or
// null if the token is not three base64url segments of JSON + signature.
function jwt_split(string $token): ?array
{
    $parts = explode('.', $token);
    if (count($parts) !== 3) {
        return null;
    }
    $headerJson = jwt_b64url_decode($parts[0]);
    $payloadJson = jwt_b64url_decode($parts[1]);
    $signature = jwt_b64url_decode($parts[2]);
    if ($headerJson === null || $payloadJson === null || $signature === null) {
        return null;
    }
    $header = json_decode($headerJson, true);
    $payload = json_decode($payloadJson, true);
    if (!is_array($header) || !is_array($payload)) {
        return null;
    }
    return [$header, $payload, $signature, $parts[0] . '.' . $parts[1]];
}

// --- JWKS fetching (cached on disk) -----------------------------------------

function jwt_cache_path(string $name): string
{
    return dirname(__DIR__) . '/cache/' . preg_replace('/[^A-Za-z0-9_-]/', '', $name) . '.json';
}

function jwt_http(string $url, ?array $postFields = null): array
{
    $ch = curl_init($url);
    $opts = [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 5,
        CURLOPT_CONNECTTIMEOUT => 5,
    ];
    if ($postFields !== null) {
        $opts[CURLOPT_POST] = true;
        $opts[CURLOPT_POSTFIELDS] = http_build_query($postFields);
        $opts[CURLOPT_HTTPHEADER] = ['Content-Type: application/x-www-form-urlencoded', 'Accept: application/json'];
    }
    curl_setopt_array($ch, $opts);
    $body = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $err = curl_error($ch);
    // (no curl_close: a no-op since PHP 8.0 and deprecated in 8.5)
    return [$code, $body === false ? '' : (string)$body, $err];
}

// The JWKS document at $url as an array of keys. Served from the cache file
// while it is younger than $maxAgeSec (or when the network fails and any
// cached copy exists); $force skips the cache, for an unknown "kid".
function jwks_fetch_cached(string $url, string $cacheFile, int $maxAgeSec, bool $force = false): ?array
{
    $cached = null;
    if (is_file($cacheFile)) {
        $data = json_decode((string)@file_get_contents($cacheFile), true);
        if (is_array($data) && isset($data['keys']) && is_array($data['keys'])) {
            $cached = $data['keys'];
            if (!$force && (time() - (int)@filemtime($cacheFile)) < $maxAgeSec) {
                return $cached;
            }
        }
    }

    // Apple's keys endpoint has been seen answering a cold request with a
    // 404 and the very next one with 200, so one non-200 gets a second try.
    $data = null;
    for ($attempt = 0; $attempt < 2 && $data === null; $attempt++) {
        [$code, $body] = jwt_http($url);
        $data = $code === 200 ? json_decode($body, true) : null;
        if (!is_array($data) || !isset($data['keys']) || !is_array($data['keys'])) {
            neon_log('apple', "jwks fetch failed (attempt " . ($attempt + 1) . "): http $code from $url");
            $data = null;
        }
    }
    if ($data === null) {
        return $cached; // stale beats nothing
    }
    $dir = dirname($cacheFile);
    if (!is_dir($dir)) {
        @mkdir($dir, 0775, true);
    }
    if (@file_put_contents($cacheFile, json_encode($data), LOCK_EX) === false) {
        neon_log('apple', 'could not write jwks cache ' . basename($cacheFile));
    }
    return $data['keys'];
}

// --- RSA public key: JWK (n, e) -> PEM ---------------------------------------

function der_length(int $len): string
{
    if ($len < 0x80) {
        return chr($len);
    }
    $bytes = ltrim(pack('N', $len), "\0");
    return chr(0x80 | strlen($bytes)) . $bytes;
}

function der_integer(string $bytes): string
{
    $bytes = ltrim($bytes, "\0");
    if ($bytes === '' || (ord($bytes[0]) & 0x80)) {
        $bytes = "\0" . $bytes; // keep it positive
    }
    return "\x02" . der_length(strlen($bytes)) . $bytes;
}

function der_sequence(string $inner): string
{
    return "\x30" . der_length(strlen($inner)) . $inner;
}

function der_bit_string(string $inner): string
{
    $inner = "\0" . $inner; // zero unused bits
    return "\x03" . der_length(strlen($inner)) . $inner;
}

// SubjectPublicKeyInfo for an RSA key from base64url modulus/exponent.
function jwk_rsa_to_pem(string $n, string $e): ?string
{
    $nBytes = jwt_b64url_decode($n);
    $eBytes = jwt_b64url_decode($e);
    if ($nBytes === null || $eBytes === null || $nBytes === '' || $eBytes === '') {
        return null;
    }
    $rsaOid = "\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01"; // 1.2.840.113549.1.1.1
    $algorithm = der_sequence($rsaOid . "\x05\x00");
    $publicKey = der_sequence(der_integer($nBytes) . der_integer($eBytes));
    $spki = der_sequence($algorithm . der_bit_string($publicKey));
    return "-----BEGIN PUBLIC KEY-----\n" . chunk_split(base64_encode($spki), 64, "\n") . "-----END PUBLIC KEY-----\n";
}

// --- RS256 verification -----------------------------------------------------

function jwks_find(array $jwks, string $kid): ?array
{
    foreach ($jwks as $key) {
        if (is_array($key) && ($key['kid'] ?? null) === $kid && ($key['kty'] ?? '') === 'RSA') {
            return $key;
        }
    }
    return null;
}

// Claims array if $token is a valid RS256 JWT signed by a key in $jwks
// (matched on "kid"), else null. Claim values are NOT checked here.
function jwt_verify_rs256(string $token, array $jwks): ?array
{
    $parts = jwt_split($token);
    if (!$parts) {
        return null;
    }
    [$header, $payload, $signature, $signingInput] = $parts;
    if (($header['alg'] ?? '') !== 'RS256' || empty($header['kid']) || !is_string($header['kid'])) {
        return null;
    }
    $key = jwks_find($jwks, $header['kid']);
    if (!$key || empty($key['n']) || empty($key['e'])) {
        return null;
    }
    $pem = jwk_rsa_to_pem((string)$key['n'], (string)$key['e']);
    if ($pem === null) {
        return null;
    }
    $pub = openssl_pkey_get_public($pem);
    if ($pub === false) {
        return null;
    }
    $ok = openssl_verify($signingInput, $signature, $pub, OPENSSL_ALGO_SHA256);
    return $ok === 1 ? $payload : null;
}

// Verify against the JWKS at $url, refetching once (bypassing the cache) when
// the token names a "kid" the cached document does not know — Apple rotates.
function jwt_verify_rs256_from_url(string $token, string $url, string $cacheFile, int $maxAgeSec = 86400): ?array
{
    $parts = jwt_split($token);
    if (!$parts) {
        return null;
    }
    $kid = (string)($parts[0]['kid'] ?? '');
    $jwks = jwks_fetch_cached($url, $cacheFile, $maxAgeSec);
    if ($jwks !== null && $kid !== '' && !jwks_find($jwks, $kid)) {
        $jwks = jwks_fetch_cached($url, $cacheFile, $maxAgeSec, true);
    }
    if ($jwks === null) {
        return null;
    }
    return jwt_verify_rs256($token, $jwks);
}

// --- Apple client secret (ES256) and token endpoints ------------------------

// Apple's "client secret" is a JWT we sign with the Sign in with Apple key
// (.p8) from the developer portal. Valid for an hour; minted per request.
function apple_client_secret(string $teamId, string $keyId, string $bundleId, string $p8Path): ?string
{
    $pem = @file_get_contents($p8Path);
    if ($pem === false || $pem === '') {
        neon_log('apple', 'client secret: private key file unreadable');
        return null;
    }
    $priv = openssl_pkey_get_private($pem);
    if ($priv === false) {
        neon_log('apple', 'client secret: private key could not be parsed');
        return null;
    }
    $now = time();
    $header = jwt_b64url_encode(json_encode(['alg' => 'ES256', 'kid' => $keyId]));
    $payload = jwt_b64url_encode(json_encode([
        'iss' => $teamId,
        'iat' => $now,
        'exp' => $now + 3600,
        'aud' => 'https://appleid.apple.com',
        'sub' => $bundleId,
    ]));
    $signingInput = $header . '.' . $payload;
    $der = '';
    if (!openssl_sign($signingInput, $der, $priv, OPENSSL_ALGO_SHA256)) {
        neon_log('apple', 'client secret: openssl_sign failed');
        return null;
    }
    $raw = ecdsa_der_to_raw($der, 32);
    if ($raw === null) {
        neon_log('apple', 'client secret: signature was not a DER ECDSA-Sig-Value');
        return null;
    }
    return $signingInput . '.' . jwt_b64url_encode($raw);
}

// DER SEQUENCE { INTEGER r, INTEGER s } -> fixed-width R||S (JOSE format).
function ecdsa_der_to_raw(string $der, int $width): ?string
{
    $pos = 0;
    $len = strlen($der);
    if ($len < 8 || ord($der[$pos++]) !== 0x30) {
        return null;
    }
    $seqLen = ord($der[$pos++]);
    if ($seqLen & 0x80) {
        $pos += $seqLen & 0x7f; // long form: skip the length bytes
    }
    $out = '';
    for ($i = 0; $i < 2; $i++) {
        if ($pos >= $len || ord($der[$pos++]) !== 0x02) {
            return null;
        }
        $intLen = ord($der[$pos++]);
        if ($intLen & 0x80) {
            $n = $intLen & 0x7f;
            $intLen = 0;
            for ($j = 0; $j < $n; $j++) {
                $intLen = ($intLen << 8) | ord($der[$pos++]);
            }
        }
        $int = substr($der, $pos, $intLen);
        $pos += $intLen;
        $int = ltrim($int, "\0");
        if (strlen($int) > $width) {
            return null;
        }
        $out .= str_pad($int, $width, "\0", STR_PAD_LEFT);
    }
    return $out;
}

// Swap a one-time authorization code for tokens. Returns Apple's decoded JSON
// (access_token, refresh_token, id_token, ...) or null.
function apple_token_exchange(string $code, string $clientSecret, string $bundleId): ?array
{
    [$httpCode, $body] = jwt_http('https://appleid.apple.com/auth/token', [
        'client_id' => $bundleId,
        'client_secret' => $clientSecret,
        'code' => $code,
        'grant_type' => 'authorization_code',
    ]);
    $data = json_decode($body, true);
    if ($httpCode !== 200 || !is_array($data) || empty($data['refresh_token'])) {
        neon_log('apple', "token exchange failed: http $httpCode" . (is_array($data) && isset($data['error']) ? ' ' . $data['error'] : ''));
        return null;
    }
    return $data;
}

// Revoke a refresh token (App Store rule: deleting the account must revoke
// the Sign in with Apple grant). True on Apple's 200.
function apple_token_revoke(string $refreshToken, string $clientSecret, string $bundleId): bool
{
    [$httpCode, $body] = jwt_http('https://appleid.apple.com/auth/revoke', [
        'client_id' => $bundleId,
        'client_secret' => $clientSecret,
        'token' => $refreshToken,
        'token_type_hint' => 'refresh_token',
    ]);
    if ($httpCode !== 200) {
        $data = json_decode($body, true);
        neon_log('apple', "token revoke failed: http $httpCode" . (is_array($data) && isset($data['error']) ? ' ' . $data['error'] : ''));
        return false;
    }
    return true;
}

// True when config.local.php holds everything needed to talk to Apple's token
// endpoints (the identity-token login works without any of it).
function apple_server_credentials_ready(): bool
{
    return defined('APPLE_TEAM_ID') && APPLE_TEAM_ID !== ''
        && defined('APPLE_KEY_ID') && APPLE_KEY_ID !== ''
        && defined('APPLE_PRIVATE_KEY_PATH') && APPLE_PRIVATE_KEY_PATH !== ''
        && is_file(APPLE_PRIVATE_KEY_PATH);
}
