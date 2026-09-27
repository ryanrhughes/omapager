# Threat model

## Assets and adversaries

Assets: HOME files, SSH/GPG keys, browser sessions, developer/API credentials,
notification and phone-message contents, OTPs, clipboard, localhost/LAN services,
desktop integrity, shell configuration and confidence in displayed identities.

Adversaries: a malicious permitted web-notification origin; a compromised local
sender; a hostile forwarded phone notification; a compromised CI/dependency tool;
and a future developer accidentally adding a bypass. App names and desktop hints
are claims, not authenticated identity. Matching a sender's claimed PID or a
window title does not prove origin.

## Boundaries

| Input | Capability | Control |
| --- | --- | --- |
| Body/source/link | Desktop URL handler | One Security.js broker, strict canonical ASCII allowlist |
| Markup/summary | Qt rendering | Escape then restore small formatting list, plain-text labels |
| Image hint | File/network read | No sender file/HTTP image URLs; only internal qsimage handles |
| Icon name | Filesystem lookup | Bounded names, no glob/path traversal, approved local roots |
| Website/redirect/DNS/image | Network and decoder | Opt-in, public pinned address, TLS validation, caps, sandbox |
| Notification row | Persistent state | Separate sanitisation, private atomic files, bounded retention |
| Action/reply/clipboard | External side effect | Explicit user action, argv, bounded values, exact reply matching |
| omarchy-exec-argv hint | Process exec | Screenshot-editor allowlist; separately brokered local-file opening and PID-only crash diagnosis; re-parse on activate; never persisted |
| Window focus target | Hyprland Lua | Compositor hexadecimal address only |
| Helper process | HOME/network | Bubblewrap fail-closed profiles |
| GitHub PR | CI token/tools | SHA-pinned actions, read-only default, no secrets or privileged PR trigger |

## Residual risks and exclusions

The Quickshell process remains the desktop's unsandboxed notification/UI process.
A Qt/QML/image-provider vulnerability is outside helper isolation. The notification
server receives raw D-Bus data before our application bounds run. Same-user D-Bus
clients can post spoofed messages and invoke the existing IPC action verbs; these
verbs are not an authentication boundary. KDE helper filesystem isolation does
not mediate destinations on the session bus. Restricting that bus needs a proxy
or daemon redesign and separate integration work.

The two first-party action names do not authenticate their sender. A claimed
`omarchy-action` notification can offer an explicit click to open a local file
or diagnose a numeric PID; it cannot pass arbitrary URLs or sender-written crash
metadata to those commands. Local-file checks reject final symlinks, special
files, executable files and `.desktop` launchers, but the desktop application
reopens the path. Same-user replacements after the check and vulnerabilities in
the user's selected file viewer are not prevented by this broker. Crash diagnosis
uses the user's configured agent and existing system crash data, not a sandboxed
or read-only agent. Neither action runs without activation.

Kernel/firmware compromise, physical access to an unlocked session and an attacker
already executing arbitrary code as the logged-in user are outside the promised
boundary. Path checks refuse static symlink attacks; they are not a proof against
a same-user process racing directory replacement. Files already backed up before
redaction are not securely erased. OTP recognition is heuristic; unknown secret
formats and password-reset links can remain in ordinary history. Disable history
for stronger message privacy. Clipboard conditional clearing has the usual race
between checking and clearing; it is not an atomic compare-and-swap.

Remote SVGs are rejected, including a cache entry left behind by a build that
predates that check — a cache hit is re-validated against today's raster
policy, not trusted merely because it already exists on disk. Local theme
SVGs remain trusted; user-installed themes and application directories are
user-controlled trusted configuration. A remote icon request may still reveal
IP and timing when explicitly enabled. Domain ownership/public DNS does not
imply a benign destination or prevent phishing.

Notification-derived text is treated as untrusted for classification, not
only for rendering: heuristics that decide "is this a secret" or "is this a
number" are themselves adversarial-input surfaces. A verification-keyword
heuristic that trusted the keyword alone previously misclassified ordinary
product names ("Visual Studio Code") as secrets, destructively, on every
restore. The Python detector now requires a distinct nearby code-shaped
token; it remains a heuristic, not a proof, and an unusual OTP format can
still be missed in either direction.
