<?php
// Support page — linked from the login and settings modals, the iOS app and
// the App Store listing (App Store requires a support URL).
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
    <title>Support — Nitro Nebula</title>
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
      <h1>Support</h1>
      <p class="doc-meta">Nitro Nebula · help and contact</p>

      <h2>How to play</h2>
      <ul>
        <li>Pick a difficulty on the home screen. Steer with the mouse, <kbd>W</kbd> <kbd>A</kbd>
          <kbd>S</kbd> <kbd>D</kbd> or the arrow keys; on a phone or in the app, drag with a
          finger.</li>
        <li>Dodge asteroids and collect the glowing treats for points and hull repair. Grab the
          red <strong>W</strong> orb and your ship fires automatically.</li>
        <li>Power-ups drift by now and then: shields, magnets, slow-motion and more. Coins buy
          skins, trails and fires in the Tailor.</li>
        <li><strong>Two Player</strong> shares one screen (or one keyboard). <strong>Online Two
          Player</strong> links two accounts: one player opens a lobby and shares the game code,
          the other joins from the Friends page. The web game pairs with the web game and the
          iOS app with the iOS app — both players need to be on the same version.</li>
        <li>An account is optional. With one, your best scores go on the leaderboard under your
          call sign.</li>
      </ul>

      <h2>Reporting an offensive call sign</h2>
      <p>Call signs appear on the leaderboard and in online lobbies. If you see one that is
        offensive, email <a href="mailto:brian.rosenthal@gmail.com">brian.rosenthal@gmail.com</a>
        with the call sign and where you saw it. We review reports promptly and will rename or
        remove the account.</p>

      <h2>Deleting your account</h2>
      <p>In the iOS app: Settings → Account → Delete Account. Your account, scores and online-play
        records are removed immediately. On the web, or if you no longer have the app, email
        <a href="mailto:brian.rosenthal@gmail.com">brian.rosenthal@gmail.com</a> from the address
        on the account and we will delete it for you.</p>

      <h2>Trouble logging in</h2>
      <ul>
        <li>Forgot your password? Use <em>Forgot password?</em> on the login screen to get a
          reset link by email.</li>
        <li>If you created the account with Google or Apple, use that button instead of the
          password form. A password can be added later with the reset link.</li>
        <li>Online play needs both players logged in and on the same version (web or app).</li>
      </ul>

      <h2>Contact</h2>
      <p>Anything else — bugs, ideas, questions:
        <a href="mailto:brian.rosenthal@gmail.com">brian.rosenthal@gmail.com</a></p>

      <nav class="doc-nav">
        <a href="./">Back to the game</a>
        <a href="privacy.php">Privacy policy</a>
      </nav>
    </main>
  </body>
</html>
