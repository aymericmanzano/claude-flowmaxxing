# Security Policy

## Supported versions

Only the latest published release receives security fixes.

## Reporting a vulnerability

Please report vulnerabilities privately, using GitHub's private vulnerability reporting: open the **Security** tab of this repository and choose **Report a vulnerability**.

Please do not open a public issue or pull request for a security problem.

This app reads the Claude Code OAuth token from the macOS Keychain and renews it, so anything that could expose or misuse that token is in scope. Reports about how the app stores, logs or transmits it are especially welcome. One known limitation is documented in the README: during a keychain write, the credentials are briefly visible in the process list.

You will get a reply as soon as I can, usually within a few days. Once a fix is released, the advisory is published with credit to the reporter if they wish.
