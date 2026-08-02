<?php
// GET: bootstrap call the game makes on page load. Returns login state, the
// CSRF token for subsequent POSTs, and the Google client ID.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

$user = null;
try {
    $user = current_user();
} catch (PDOException $e) {
    // Database down/unconfigured: report logged-out but still hand out the
    // CSRF token so the client can distinguish "offline" from "logged out".
    error_log('session.php db error: ' . $e->getMessage());
    json_out([
        'loggedIn' => false,
        'user' => null,
        'csrf' => $_SESSION['csrf'],
        'googleClientId' => GOOGLE_CLIENT_ID,
        'offline' => true,
    ]);
}

json_out([
    'loggedIn' => $user !== null,
    'user' => $user ? user_payload($user) : null,
    'csrf' => $_SESSION['csrf'],
    'googleClientId' => GOOGLE_CLIENT_ID,
]);
