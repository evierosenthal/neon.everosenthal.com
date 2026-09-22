<?php
// GET: bootstrap call the game (and the iOS app) makes on launch. Returns
// login state, the CSRF token for subsequent POSTs, the Google client ID and
// apiVersion — bump that when a response shape changes incompatibly so an
// old app build can say "update me" instead of misreading the JSON.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

$user = null;
try {
    $user = current_user();
} catch (PDOException $e) {
    // Database down/unconfigured: report logged-out but still hand out the
    // CSRF token so the client can distinguish "offline" from "logged out".
    neon_log('db', 'session.php db error: ' . $e->getMessage());
    json_out([
        'loggedIn' => false,
        'user' => null,
        'csrf' => $_SESSION['csrf'],
        'googleClientId' => GOOGLE_CLIENT_ID,
        'apiVersion' => 1,
        'offline' => true,
    ]);
}

json_out([
    'loggedIn' => $user !== null,
    'user' => $user ? user_payload($user) : null,
    'csrf' => $_SESSION['csrf'],
    'googleClientId' => GOOGLE_CLIENT_ID,
    'apiVersion' => 1,
]);
