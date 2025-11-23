# CRM114 Fantasy Workstation

A private command-line retreat that boots an opulent Bubble Tea interface the moment you run `ssh crm114@localhost`.

## What you get
- **Instant immersion** – every SSH session launches a Wish-powered TUI that feels like a handcrafted terminal desktop, no shell juggling required.
- **Hidden companion** – everything runs under a concealed macOS account (`crm114`) so logs, configs, and binaries stay tucked away from the main profile.
- **Charm-native polish** – Bubble Tea drives the UI, Lip Gloss paints the layout, Glamour renders docs, and Charm services keep long-term state in sync.
- **Local-only safety** – the workstation only listens on `127.0.0.1`, making it perfect for pairing with agents, ambient copilots, or personal rituals without exposing a network surface.

## How a session works
1. You initiate `ssh crm114@localhost` (an alias can shorten this further).
2. macOS’s sshd hands the session to a ForceCommand wrapper.
3. The wrapper launches the Wish binary stored in `/usr/local/libexec/crm114`, which spins up a fresh Bubble Tea program for your terminal.
4. When you exit the TUI, the session closes cleanly—no lingering shells, no stray processes.

## Getting access
- **One-line installer (coming soon):** `curl -fsSL https://crm114.computer/install.sh | sh` brings a Gum-driven flow that secures sudo, provisions the hidden user, tightens sshd, installs Wish/Gum/Go via Homebrew, and validates the login path.
- **Manual preview (for pioneers):**
  1. Create `/Users/.crm114`, flag the account as hidden, and keep its home directory private.
  2. Enable Remote Login for that user only, force sshd to bind to `127.0.0.1`, and disable password auth.
  3. Generate a dedicated ed25519 keypair (`~/.ssh/crm114_fantasy`) and drop the public key into `/Users/.crm114/.ssh/authorized_keys`.
  4. Install the Wish binary + launcher under `/usr/local/libexec/crm114`, add the launcher to `/etc/shells`, and make it the user’s shell.
  5. Test with `ssh crm114@localhost` and watch the Bubble Tea interface appear.

## Security posture
- SSH is locked to loopback (`ListenAddress 127.0.0.1`) with key-only authentication and forwarding disabled for the hidden user.
- The `crm114` account remains absent from standard macOS login experiences; keep it out of FileVault unlock lists to avoid showing up pre-boot.
- Every sshd change is backed up before edits, and uninstall scripts will restore the previous state, delete the hidden user, and remove binaries.
- Dedicated workstation keys keep your usual SSH identities untouched; Charm account linking can add encrypted sync later without weakening the boundary.

## Status & roadmap
- ✅ Research on Charm stack integration, macOS hidden-user behavior, SSH hardening, and Gum installer UX.
- 🔄 Authoring Gum installer script, Wish-based TUI binary, and uninstall path.
- 🔜 Shipping nightly builds plus a polished README-driven onboarding story.

Follow progress inside `docs/research/` for deep dives and keep an eye on this README for installer availability.
