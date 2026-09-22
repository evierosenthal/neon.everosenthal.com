<?php
// Online two-player lobbies. One endpoint, many actions:
//
//   GET  ?action=inbox                 invites waiting for me + the game I'm in
//   GET  ?action=status&code=X         lobby state (also my "still here" heartbeat)
//   GET  ?action=signals&code=X&after=N  WebRTC messages from the other side
//   POST {action: 'create', code, mode, platform?}  open a lobby I host
//   POST {action: 'invite', username, code}  ask a friend into my lobby
//   POST {action: 'join', code, platform?}   take the guest seat
//   POST {action: 'decline', id}          dismiss an invite
//   POST {action: 'start', code}          host: begin (guest must be seated)
//   POST {action: 'leave', code}          host closes the lobby / guest steps out
//   POST {action: 'finish', code}         either side: the round is over
//   POST {action: 'signal', code, payload}  relay a WebRTC offer/answer
//
// The server only matchmakes and relays signaling; the game itself runs
// peer-to-peer over a WebRTC data channel (host simulates, guest renders).
//
// platform is 'web' (default; browsers, WebRTC) or 'ios' (the app, Game
// Center). The two transports cannot talk to each other, so a join whose
// platform differs from the host's is refused with platform_mismatch. The
// iOS app relays {type:'gc', gamePlayerID} through 'signal' instead of SDP.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

const LOBBY_MODES = ['easy', 'medium', 'hard'];
const LOBBY_PLATFORMS = ['web', 'ios'];
const LOBBY_STALE_SEC = 45;      // no heartbeat for this long = that side left
const LOBBY_MAX_AGE_SEC = 3600;  // lobbies older than an hour are swept

$user = require_user();
$userId = (int)$user['id'];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    require_post_with_csrf();
    $in = json_input();
    $action = (string)($in['action'] ?? '');
} else {
    $in = $_GET;
    $action = (string)($in['action'] ?? '');
}

function stamp(int $offsetSec = 0): string
{
    return date('Y-m-d H:i:s', time() + $offsetSec);
}

function clean_platform(array $in): string
{
    $platform = (string)($in['platform'] ?? 'web');
    if (!in_array($platform, LOBBY_PLATFORMS, true)) {
        json_error('bad_platform', 'platform must be "web" or "ios".');
    }
    return $platform;
}

function clean_code(string $raw): string
{
    $code = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $raw));
    if (strlen($code) < 4 || strlen($code) > 12) {
        json_error('bad_code', 'Game codes are 4 to 12 letters or numbers.');
    }
    return $code;
}

// Sweep lobbies nobody is keeping alive so a code can be reused.
function sweep(): void
{
    $db = db();
    $db->prepare("DELETE FROM games WHERE status = 'finished' OR host_seen_at < ? OR created_at < ?")
        ->execute([stamp(-LOBBY_STALE_SEC * 4), stamp(-LOBBY_MAX_AGE_SEC)]);
    $db->prepare('DELETE FROM game_signals WHERE created_at < ?')->execute([stamp(-600)]);
    $db->prepare('DELETE FROM game_invites WHERE created_at < ?')->execute([stamp(-86400)]);
}

function load_game(string $code): ?array
{
    $stmt = db()->prepare(
        'SELECT g.*, h.username AS host_name, u.username AS guest_name
         FROM games g
         JOIN users h ON h.id = g.host_user_id
         LEFT JOIN users u ON u.id = g.guest_user_id
         WHERE g.code = ?'
    );
    $stmt->execute([$code]);
    $game = $stmt->fetch();
    return $game ?: null;
}

function game_payload(array $g, int $me): array
{
    $stale = stamp(-LOBBY_STALE_SEC);
    return [
        'code' => $g['code'],
        'mode' => $g['mode'],
        'status' => $g['status'],
        'host' => $g['host_name'],
        'guest' => $g['guest_name'] ?: null,
        'you' => (int)$g['host_user_id'] === $me ? 'host'
            : ((int)($g['guest_user_id'] ?? 0) === $me ? 'guest' : null),
        'hostOnline' => $g['host_seen_at'] >= $stale,
        'guestOnline' => !empty($g['guest_user_id']) && ($g['guest_seen_at'] ?? '') >= $stale,
        'hostPlatform' => $g['host_platform'] ?? 'web',
        'guestPlatform' => !empty($g['guest_user_id']) ? ($g['guest_platform'] ?? null) : null,
    ];
}

// The game I'm currently part of (open or started, host still alive), if any.
function my_game(int $me): ?array
{
    $stmt = db()->prepare(
        'SELECT g.*, h.username AS host_name, u.username AS guest_name
         FROM games g
         JOIN users h ON h.id = g.host_user_id
         LEFT JOIN users u ON u.id = g.guest_user_id
         WHERE (g.host_user_id = ? OR g.guest_user_id = ?)
           AND g.status IN (\'open\', \'started\') AND g.host_seen_at >= ?
         ORDER BY g.created_at DESC LIMIT 1'
    );
    $stmt->execute([$me, $me, stamp(-LOBBY_STALE_SEC)]);
    $g = $stmt->fetch();
    return $g ?: null;
}

function require_member(string $code, int $me): array
{
    $g = load_game($code);
    if (!$g) {
        json_error('not_found', 'No game with that code.', 404);
    }
    if ((int)$g['host_user_id'] !== $me && (int)($g['guest_user_id'] ?? 0) !== $me) {
        json_error('forbidden', 'You are not in that game.', 403);
    }
    return $g;
}

function touch_seen(array $g, int $me): void
{
    $col = (int)$g['host_user_id'] === $me ? 'host_seen_at' : 'guest_seen_at';
    db()->prepare("UPDATE games SET $col = ? WHERE code = ?")->execute([stamp(), $g['code']]);
}

try {
    $db = db();

    switch ($action) {
        case 'inbox': {
            $stmt = $db->prepare(
                'SELECT i.id, i.code, f.username AS from_name, g.mode
                 FROM game_invites i
                 JOIN users f ON f.id = i.from_user_id
                 JOIN games g ON g.code = i.code
                 WHERE i.to_user_id = ? AND i.status = \'pending\'
                   AND g.status = \'open\' AND g.host_seen_at >= ?
                 ORDER BY i.id DESC LIMIT 20'
            );
            $stmt->execute([$userId, stamp(-LOBBY_STALE_SEC)]);
            $invites = [];
            foreach ($stmt->fetchAll() as $row) {
                $invites[] = [
                    'id' => (int)$row['id'],
                    'code' => $row['code'],
                    'from' => $row['from_name'],
                    'mode' => $row['mode'],
                ];
            }
            $mine = my_game($userId);
            json_out(['invites' => $invites, 'game' => $mine ? game_payload($mine, $userId) : null]);
        }

        case 'status': {
            $code = clean_code((string)($in['code'] ?? ''));
            $g = require_member($code, $userId);
            touch_seen($g, $userId);
            // A guest who stopped polling gives their seat back while the lobby is open.
            if ($g['status'] === 'open' && !empty($g['guest_user_id']) && ($g['guest_seen_at'] ?? '') < stamp(-LOBBY_STALE_SEC)) {
                $db->prepare('UPDATE games SET guest_user_id = NULL, guest_seen_at = NULL, guest_platform = NULL WHERE code = ?')->execute([$code]);
            }
            json_out(['game' => game_payload(load_game($code), $userId)]);
        }

        case 'signals': {
            $code = clean_code((string)($in['code'] ?? ''));
            $g = require_member($code, $userId);
            touch_seen($g, $userId);
            $other = (int)$g['host_user_id'] === $userId ? 'guest' : 'host';
            $stmt = $db->prepare('SELECT id, payload FROM game_signals WHERE code = ? AND from_role = ? AND id > ? ORDER BY id ASC LIMIT 50');
            $stmt->execute([$code, $other, (int)($in['after'] ?? 0)]);
            $messages = [];
            foreach ($stmt->fetchAll() as $row) {
                $messages[] = ['id' => (int)$row['id'], 'payload' => json_decode($row['payload'], true)];
            }
            json_out(['messages' => $messages, 'status' => $g['status']]);
        }

        case 'create': {
            $code = clean_code((string)($in['code'] ?? ''));
            $mode = (string)($in['mode'] ?? '');
            if (!in_array($mode, LOBBY_MODES, true)) {
                json_error('bad_mode', 'Pick Easy, Medium or Hard.');
            }
            $platform = clean_platform($in);
            sweep();
            $existing = load_game($code);
            if ($existing && (int)$existing['host_user_id'] !== $userId && $existing['host_seen_at'] >= stamp(-LOBBY_STALE_SEC)) {
                json_error('code_taken', 'That game code is in use — pick another.', 409);
            }
            // One lobby per host: anything else I was hosting closes.
            $db->prepare('DELETE FROM games WHERE host_user_id = ? OR code = ?')->execute([$userId, $code]);
            $db->prepare('DELETE FROM game_signals WHERE code = ?')->execute([$code]);
            $db->prepare('INSERT INTO games (code, host_user_id, guest_user_id, mode, host_platform, guest_platform, status, host_seen_at, guest_seen_at, created_at)
                          VALUES (?, ?, NULL, ?, ?, NULL, \'open\', ?, NULL, ?)')
                ->execute([$code, $userId, $mode, $platform, stamp(), stamp()]);
            json_out(['game' => game_payload(load_game($code), $userId)]);
        }

        case 'invite': {
            $code = clean_code((string)($in['code'] ?? ''));
            $name = trim((string)($in['username'] ?? ''));
            if ($name === '') {
                json_error('bad_username', 'Type your friend\'s username.');
            }
            $stmt = $db->prepare('SELECT id, username FROM users WHERE LOWER(username) = LOWER(?) LIMIT 1');
            $stmt->execute([$name]);
            $friend = $stmt->fetch();
            if (!$friend) {
                json_error('no_such_user', 'No pilot named "' . $name . '" — check the spelling.', 404);
            }
            if ((int)$friend['id'] === $userId) {
                json_error('self_invite', 'That is you! Invite someone else.');
            }
            $g = load_game($code);
            if (!$g || (int)$g['host_user_id'] !== $userId || $g['status'] !== 'open') {
                json_error('no_lobby', 'Open a lobby with that code first (Two Player → Create Game).', 404);
            }
            $db->prepare('DELETE FROM game_invites WHERE code = ? AND from_user_id = ? AND to_user_id = ?')
                ->execute([$code, $userId, (int)$friend['id']]);
            $db->prepare('INSERT INTO game_invites (code, from_user_id, to_user_id, status, created_at) VALUES (?, ?, ?, \'pending\', ?)')
                ->execute([$code, $userId, (int)$friend['id'], stamp()]);
            json_out(['ok' => true, 'to' => $friend['username'], 'code' => $code]);
        }

        case 'join': {
            $code = clean_code((string)($in['code'] ?? ''));
            $platform = clean_platform($in);
            $g = load_game($code);
            if (!$g || $g['host_seen_at'] < stamp(-LOBBY_STALE_SEC)) {
                json_error('not_found', 'No open game with that code.', 404);
            }
            if ((int)$g['host_user_id'] === $userId) {
                json_error('own_game', 'That is your own lobby — wait for a friend to join it.');
            }
            if ($g['status'] !== 'open') {
                json_error('started', 'That game has already started.', 409);
            }
            $guestId = (int)($g['guest_user_id'] ?? 0);
            $guestFresh = ($g['guest_seen_at'] ?? '') >= stamp(-LOBBY_STALE_SEC);
            if ($guestId && $guestId !== $userId && $guestFresh) {
                json_error('full', 'Someone already joined that game.', 409);
            }
            if (($g['host_platform'] ?? 'web') !== $platform) {
                json_error('platform_mismatch', 'Online play pairs app with app and web with web — your friend is on the other version.', 409);
            }
            // Leave any other lobby I was sitting in.
            $db->prepare("UPDATE games SET guest_user_id = NULL, guest_seen_at = NULL, guest_platform = NULL WHERE guest_user_id = ? AND status = 'open'")->execute([$userId]);
            $db->prepare('UPDATE games SET guest_user_id = ?, guest_seen_at = ?, guest_platform = ? WHERE code = ?')->execute([$userId, stamp(), $platform, $code]);
            $db->prepare("UPDATE game_invites SET status = 'accepted' WHERE code = ? AND to_user_id = ? AND status = 'pending'")->execute([$code, $userId]);
            json_out(['game' => game_payload(load_game($code), $userId)]);
        }

        case 'decline': {
            $db->prepare("UPDATE game_invites SET status = 'declined' WHERE id = ? AND to_user_id = ?")
                ->execute([(int)($in['id'] ?? 0), $userId]);
            json_out(['ok' => true]);
        }

        case 'start': {
            $code = clean_code((string)($in['code'] ?? ''));
            $g = require_member($code, $userId);
            if ((int)$g['host_user_id'] !== $userId) {
                json_error('forbidden', 'Only the host can start.', 403);
            }
            if (empty($g['guest_user_id']) || ($g['guest_seen_at'] ?? '') < stamp(-LOBBY_STALE_SEC)) {
                json_error('no_guest', 'Wait for a friend to join first.');
            }
            $db->prepare('DELETE FROM game_signals WHERE code = ?')->execute([$code]);
            $db->prepare("UPDATE games SET status = 'started', host_seen_at = ? WHERE code = ?")->execute([stamp(), $code]);
            json_out(['game' => game_payload(load_game($code), $userId)]);
        }

        case 'leave': {
            $code = clean_code((string)($in['code'] ?? ''));
            $g = load_game($code);
            if ($g) {
                if ((int)$g['host_user_id'] === $userId) {
                    $db->prepare('DELETE FROM games WHERE code = ?')->execute([$code]);
                    $db->prepare('DELETE FROM game_signals WHERE code = ?')->execute([$code]);
                    $db->prepare('DELETE FROM game_invites WHERE code = ?')->execute([$code]);
                } elseif ((int)($g['guest_user_id'] ?? 0) === $userId) {
                    if ($g['status'] === 'open') {
                        $db->prepare('UPDATE games SET guest_user_id = NULL, guest_seen_at = NULL, guest_platform = NULL WHERE code = ?')->execute([$code]);
                    } else {
                        $db->prepare("UPDATE games SET status = 'finished' WHERE code = ?")->execute([$code]);
                    }
                }
            }
            json_out(['ok' => true]);
        }

        case 'finish': {
            $code = clean_code((string)($in['code'] ?? ''));
            $g = require_member($code, $userId);
            $db->prepare("UPDATE games SET status = 'finished' WHERE code = ?")->execute([$code]);
            json_out(['ok' => true]);
        }

        case 'signal': {
            $code = clean_code((string)($in['code'] ?? ''));
            $g = require_member($code, $userId);
            // Any JSON object up to 200 KB: a WebRTC {type:'offer'|'answer', sdp}
            // from the web game, or {type:'gc', gamePlayerID} from the iOS app.
            $payload = $in['payload'] ?? null;
            $encoded = json_encode($payload);
            if (!is_array($payload) || $encoded === false || strlen($encoded) > 200000) {
                json_error('bad_signal', 'Signal payload must be a small JSON object.');
            }
            $role = (int)$g['host_user_id'] === $userId ? 'host' : 'guest';
            $db->prepare('INSERT INTO game_signals (code, from_role, payload, created_at) VALUES (?, ?, ?, ?)')
                ->execute([$code, $role, $encoded, stamp()]);
            json_out(['ok' => true]);
        }

        default:
            json_error('bad_action', 'Unknown action.');
    }
} catch (PDOException $e) {
    neon_log('db', 'games.php db error (' . $action . '): ' . $e->getMessage());
    json_error('server_error', 'Online play is unavailable right now — the database may need its migrations run.', 500);
}
