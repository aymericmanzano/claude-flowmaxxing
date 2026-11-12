# Claude Flowmaxxing

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A small native macOS app that lives in your MacBook's notch and keeps you in the flow while you run Claude Code sessions with music on.

- A pixel Claude appears in the notch as soon as a Claude Code session is open, and walks while a reply is being generated. When no session is open, the notch closes back to its normal size.
- The right side of the notch shows your 5-hour usage as a ring. Click it to switch to the 7-day or the per-model weekly limit.
- When a session finishes, a banner slides out of the notch for 6 seconds. Click it to jump straight to that session in the Claude desktop app.
- Click the notch to open the panel: 5-hour, 7-day and per-model limits with their reset times, extra usage credits, today's estimated cost, and your most used model over 7 days.
- A second page controls your music: artwork, track, progress, play/pause, previous and next, for Spotify, Apple Music and VLC (title only for VLC). With any other player, such as Deezer, Tidal or a browser tab, the buttons send the keyboard media keys. Swipe with two fingers to move between pages.

The interface is in French for now.

## Requirements

- A MacBook with a notch, on Apple Silicon
- macOS 14 Sonoma or later
- Claude Code, signed in with a Claude subscription (the usage limits come from your account)
- Spotify, Apple Music or VLC, optional

## Build and install

```bash
git clone https://github.com/aymericmanzano/claude-flowmaxxing.git
cd claude-flowmaxxing
./build.sh
```

`build.sh` compiles a release build with Swift Package Manager, assembles `build/ClaudeFlowmaxxing.app`, signs it ad hoc and creates `build/ClaudeFlowmaxxing.dmg`. Open the DMG and drag the app to Applications.

The app has no Apple Developer ID signature. On first launch, right-click the app and choose Open, then confirm. macOS asks once per music app for permission to control it.

## How it works

Everything runs locally. The app talks to two Anthropic endpoints and to nothing else.

| Feature | Source |
|---|---|
| Open and busy sessions | `~/.claude/sessions/<pid>.json`, written by Claude Code for each session, checked every second |
| Jump to a finished session | `claude://code/continue?session=<id>` deep link, handled by the Claude desktop app |
| Usage limits and credits | `GET https://api.anthropic.com/api/oauth/usage`, every 60 seconds, with the OAuth token Claude Code stores in the login keychain |
| Estimated cost | Local parsing of the transcripts in `~/.claude/projects`, priced at public API rates |
| Music | AppleScript for Spotify, Apple Music and VLC, only when the app is already running; keyboard media keys for other players, which needs the Accessibility permission |

### About the keychain token

Claude Code keeps its OAuth credentials in the login keychain under `Claude Code-credentials`. When the access token has expired, Claude Flowmaxxing refreshes it with the stored refresh token and writes the new credentials back to the same keychain item, the same way Claude Code does. Without this, the usage limits stop updating whenever no terminal session has refreshed the token recently.

The token never leaves your Mac except in requests to Anthropic, and it is never written to disk or to the log. The app makes at most one refresh attempt every 5 minutes. If you prefer to avoid this, do not run the app: there is no read-only mode yet.

### About the cost

The cost is an estimate at public API prices, computed from your local transcripts. With a subscription you do not pay these amounts; the figure helps you see how hard you are pushing your sessions.

## Logs and debug flags

The app writes a short diagnostic log to `~/Library/Logs/ClaudeFlowmaxxing.log`, without any token.

| Flag | Effect |
|---|---|
| `--ouvert` | Opens the panel at launch |
| `--musique` | Opens the panel on the music page |
| `--essai-fin` | Shows the "finished" banner at launch |
| `--essai-trousseau` | Tests a keychain write on a scratch item, then deletes it |

## Disclaimer

Claude Flowmaxxing is a personal side project. It is not affiliated with, endorsed by or supported by Anthropic. Claude is a trademark of Anthropic. The usage endpoint used here is undocumented and may change without notice.

## Credits

Made by [Aymeric Manzano](https://www.aymericmanzano.fr/), built with [Claude Code](https://www.anthropic.com/claude-code).

## License

MIT, see [LICENSE](LICENSE).
