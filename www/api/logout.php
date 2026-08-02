<?php
// POST {}: end the session.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();

$_SESSION = [];
if (ini_get('session.use_cookies')) {
    $p = session_get_cookie_params();
    setcookie(session_name(), '', [
        'expires' => time() - 42000,
        'path' => $p['path'],
        'secure' => $p['secure'],
        'httponly' => $p['httponly'],
        'samesite' => $p['samesite'],
    ]);
}
session_destroy();

// Fresh session so the client immediately has a working CSRF token again.
session_start();
session_regenerate_id(true);
$_SESSION['csrf'] = bin2hex(random_bytes(32));

json_out(['loggedIn' => false, 'user' => null, 'csrf' => $_SESSION['csrf']]);
