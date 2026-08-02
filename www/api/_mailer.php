<?php
// Dependency-free SMTP client, ported from portal.bronxconservatory.org's
// mailer.php (same config constants: SMTP_HOST/PORT/SECURE/USER/PASS,
// SMTP_FROM_EMAIL/SMTP_FROM_NAME). Supports implicit SSL (465) and
// STARTTLS (587), AUTH LOGIN, HTML body.
defined('NEON_API') or exit;

function send_smtp_mail(string $toEmail, string $toName, string $subject, string $html, string &$errorMessage = ''): bool
{
    if (!defined('SMTP_HOST') || !defined('SMTP_PORT') || !defined('SMTP_USER') || !defined('SMTP_PASS')) {
        $errorMessage = 'SMTP configuration missing';
        return false;
    }

    $host = SMTP_HOST;
    $port = (int)SMTP_PORT;
    $secure = defined('SMTP_SECURE') ? strtolower(SMTP_SECURE) : 'tls';
    $fromEmail = defined('SMTP_FROM_EMAIL') && SMTP_FROM_EMAIL ? SMTP_FROM_EMAIL : SMTP_USER;
    $fromName = defined('SMTP_FROM_NAME') ? SMTP_FROM_NAME : 'Neon Nebula';

    $timeout = 20;
    $transport = ($secure === 'ssl') ? "ssl://$host" : $host;
    $fp = @stream_socket_client("$transport:$port", $errno, $errstr, $timeout, STREAM_CLIENT_CONNECT);
    if (!$fp) {
        $errorMessage = "Failed to connect to $host:$port - $errstr ($errno)";
        return false;
    }
    stream_set_timeout($fp, $timeout);

    $lastResponse = '';
    $expect = function (array $codes) use ($fp, &$lastResponse): bool {
        do {
            $line = fgets($fp, 515);
            if ($line === false) {
                $lastResponse = 'Connection lost or timeout';
                return false;
            }
            $lastResponse = trim($line);
            $code = (int)substr($line, 0, 3);
            $more = isset($line[3]) && $line[3] === '-';
        } while ($more);
        return in_array($code, $codes, true);
    };
    $send = function (string $cmd) use ($fp): bool {
        return fwrite($fp, $cmd . "\r\n") !== false;
    };
    $fail = function (string $step) use ($fp, &$errorMessage, &$lastResponse): bool {
        $errorMessage = "$step failed: $lastResponse";
        fclose($fp);
        return false;
    };

    if (!$expect([220])) return $fail('SMTP greeting');

    $ehloName = $_SERVER['SERVER_NAME'] ?? 'localhost';
    if (!$send("EHLO $ehloName") || !$expect([250])) return $fail('EHLO');

    if ($secure === 'tls') {
        if (!$send('STARTTLS') || !$expect([220])) return $fail('STARTTLS');
        if (!stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) return $fail('TLS negotiation');
        if (!$send("EHLO $ehloName") || !$expect([250])) return $fail('EHLO after STARTTLS');
    }

    if (!$send('AUTH LOGIN') || !$expect([334])) return $fail('AUTH LOGIN');
    if (!$send(base64_encode(SMTP_USER)) || !$expect([334])) return $fail('SMTP username');
    if (!$send(base64_encode(SMTP_PASS)) || !$expect([235])) return $fail('SMTP password');

    if (!$send("MAIL FROM:<$fromEmail>") || !$expect([250])) return $fail('MAIL FROM');
    if (!$send("RCPT TO:<$toEmail>") || !$expect([250, 251])) return $fail('RCPT TO');
    if (!$send('DATA') || !$expect([354])) return $fail('DATA');

    if ($toName === '') $toName = $toEmail;
    $headers = [
        'Date: ' . date('r'),
        'From: ' . mb_encode_mimeheader($fromName) . " <{$fromEmail}>",
        'To: ' . mb_encode_mimeheader($toName) . " <{$toEmail}>",
        'Subject: ' . mb_encode_mimeheader($subject),
        'Message-ID: <' . bin2hex(random_bytes(16)) . '@' . parse_url(APP_BASE_URL, PHP_URL_HOST) . '>',
        'MIME-Version: 1.0',
        'Content-Type: text/html; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
    ];

    // Normalize newlines and dot-stuff the body.
    $body = preg_replace("/\r\n|\r|\n/", "\r\n", $html);
    $body = preg_replace('/^\./m', '..', $body);

    $data = implode("\r\n", $headers) . "\r\n\r\n" . $body . "\r\n.";
    if (!$send($data) || !$expect([250])) return $fail('Message data');

    $send('QUIT');
    fclose($fp);
    return true;
}
