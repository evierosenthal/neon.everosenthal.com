<?php
// Privacy policy — a standalone page linked from the login and settings
// modals, the iOS app (Settings > Account) and the App Store listing.
function asset(string $path): string
{
    $version = @filemtime(__DIR__ . '/' . $path);
    return htmlspecialchars($path . ($version ? '?v=' . $version : ''), ENT_QUOTES);
}
?><!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Privacy Policy — Nitro Nebula</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Inter:wght@300;400;600&display=swap" rel="stylesheet" />
    <link rel="stylesheet" href="<?= asset('styles.css') ?>" />
  </head>
  <body class="doc-page">
    <div class="nebula">
      <div class="nebula-blob nebula-indigo"></div>
      <div class="nebula-blob nebula-purple"></div>
      <div class="nebula-blob nebula-emerald"></div>
    </div>

    <main class="panel doc">
      <h1>Privacy Policy</h1>
      <p class="doc-meta">Nitro Nebula · effective 21 September 2026</p>

      <p>Nitro Nebula is a space arcade game made by Eve Rosenthal and published at
        <a href="https://neon.everosenthal.com">neon.everosenthal.com</a> and on the App Store.
        You can play the whole game without an account. This page explains what we store when
        you do create one, why, and how to delete it.</p>

      <h2>What we collect</h2>
      <p>Only when you create an account or log in:</p>
      <ul>
        <li>Your call sign (username) and email address.</li>
        <li>A hash of your password, if you set one. We never store the password itself.</li>
        <li>If you sign in with Google or Apple: the account identifier that service gives us for
          this game. Apple lets you hide your email; we then store the private relay address
          Apple provides.</li>
        <li>Your best score in each mode, so the leaderboard can show it.</li>
        <li>While you play online two-player: the game code you opened or joined, invites you
          sent or received, and the connection details the two players exchange through the
          server to link up. These are cleared automatically within a day.</li>
        <li>Server logs: the time, IP address and email of logins, sign-in failures and errors,
          kept for security and to fix bugs.</li>
      </ul>
      <p>Game settings, coins and cosmetics are stored on your device only (browser storage or
        the app's local storage). They are not sent to the server.</p>

      <h2>Why</h2>
      <p>To keep your scores on the leaderboard under your call sign, to let you log back in,
        to connect you with a friend for online two-player, and to keep the service secure.
        That is all. There is no advertising, no analytics or tracking, and we never sell or
        share your data.</p>

      <h2>Third parties</h2>
      <ul>
        <li><strong>Google Sign-In</strong> — if you choose it, Google confirms who you are and
          gives us your email, name and a Google account identifier.</li>
        <li><strong>Sign in with Apple</strong> — if you choose it, Apple confirms who you are and
          gives us your email (or a relay address) and an Apple account identifier.</li>
        <li><strong>Apple Game Center</strong> — in the iOS app, online two-player uses Game
          Center to connect the two devices. Apple's own privacy policy covers Game Center.</li>
      </ul>
      <p>The leaderboard shows your call sign and best scores to other players. Nothing else
        about your account is public.</p>

      <h2>How long we keep it</h2>
      <p>Account data stays until you delete the account. Online lobby data is swept within a
        day. Server logs are rotated and old entries are discarded.</p>

      <h2>Deleting your account</h2>
      <p>In the iOS app: Settings → Account → Delete Account. This removes your account, scores
        and any online-play records immediately, and revokes Sign in with Apple if you used it.
        You can also email <a href="mailto:brian.rosenthal@gmail.com">brian.rosenthal@gmail.com</a>
        from the address on the account and we will delete it for you.</p>

      <h2>Children</h2>
      <p>Nitro Nebula is not directed at children under 13, and we do not knowingly collect
        personal information from them. If you believe a child has created an account, email
        us and we will remove it.</p>

      <h2>Changes</h2>
      <p>If this policy changes, the new version is posted here with a new effective date.</p>

      <h2>Contact</h2>
      <p><a href="mailto:brian.rosenthal@gmail.com">brian.rosenthal@gmail.com</a></p>

      <nav class="doc-nav">
        <a href="./">Back to the game</a>
        <a href="support.php">Support</a>
      </nav>
    </main>
  </body>
</html>
