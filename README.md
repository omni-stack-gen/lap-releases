# lap-releases

Pre-built Linux binaries for the `lap` (Local Agent Proxy) CLI. The source
code lives in a separate (currently private) repository under the same
GitHub organization; this repo only hosts release artifacts so they can be
fetched without authentication.

---

## Quick start

### 1. Install

Linux x86_64 (aarch64 support coming once GH Actions ARM runners are wired up):

```bash
curl -fsSL https://raw.githubusercontent.com/omni-stack-gen/lap-releases/main/install.sh | bash
```

The installer:
- detects your arch via `uname -m` (must be `x86_64` or `aarch64`)
- fetches the latest tag from `releases/latest`
- downloads the binary + `SHA256SUMS` and verifies the hash
- places the binary at `~/.omnistack/bin/lap` (mode 0700)
- prints a shell-rc snippet if `~/.omnistack/bin` is not on your `$PATH`

### 2. Add to PATH

Follow the snippet the installer prints, e.g. for bash:

```bash
echo 'export PATH="$HOME/.omnistack/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
lap --version          # → lap, version 0.23.0
```

For zsh use `~/.zshrc`; for fish use `fish_add_path "$HOME/.omnistack/bin"`.

### 3. Pair with a SaaS instance

```bash
lap pair --saas-url http://<saas-host>:8000 DEMO-1234
```

`DEMO-1234` is the demo device code accepted by the bundled SaaS. For a
real deployment, ask your operator for the SaaS URL and a one-time device
code (issued from the SaaS web UI).

### 4. Run the daemon

```bash
lap run
```

`lap run` connects to the SaaS over WebSocket, registers as a worker, and
serves jobs (build / flash / run) until interrupted. On startup it does a
1.5 s background check against `releases/latest`; if a newer version is
out, you'll see one stderr line:

```
[lap update] v0.23.0 available; run "lap self update" to upgrade. (changelog: ...)
```

The check is rate-limited to once per 24 h via `~/.omnistack/.update_check`.
Disable it with `LAP_DISABLE_UPDATE_CHECK=1`.

### 5. Upgrade

```bash
lap self update
```

Downloads the latest binary, verifies SHA256, atomically replaces the
running executable, runs `--version` as a self-test, and rolls back if the
new binary doesn't pass. The previous binary is kept at `~/.omnistack/bin/lap.old`
for manual recovery if needed.

`lap self update` refuses while a `lap run` process is active (jobs in
flight). Pass `--force` to override.

---

## Pin a specific version

```bash
LAP_VERSION=v0.23.0 curl -fsSL https://raw.githubusercontent.com/omni-stack-gen/lap-releases/main/install.sh | bash
```

Useful for downgrade or for matching a specific SaaS protocol version.

## Custom install location

```bash
# Install under a different $HOME-rooted dir (no extra permission)
LAP_INSTALL_DIR="$HOME/some-other-dir/bin" \
  curl -fsSL https://raw.githubusercontent.com/omni-stack-gen/lap-releases/main/install.sh | bash

# Install to a system path (requires explicit opt-in)
LAP_INSTALL_DIR=/opt/lap LAP_ALLOW_SYSTEM_DIR=1 \
  curl -fsSL https://raw.githubusercontent.com/omni-stack-gen/lap-releases/main/install.sh | bash
```

## Uninstall

```bash
rm -rf ~/.omnistack/    # binary + pair state + job DB + caches
# Then remove the PATH line from your shell rc.
```

---

## What's included per release

Each tag `vX.Y.Z` ships:

- `lap-vX.Y.Z-linux-x86_64` — onefile binary built on `manylinux_2_28_x86_64`
  (glibc 2.28 baseline → runs on RHEL 8+, Debian 11+, Ubuntu 20.04+, modern Fedora)
- `lap-vX.Y.Z-linux-aarch64` — same, for ARM64 *(not yet available; planned)*
- `SHA256SUMS` — sha256 hashes of all binaries; install.sh verifies these
  before placing the binary in `~/.omnistack/bin/lap`

---

## Verify a release manually (without install.sh)

```bash
TAG=v0.23.0
ARCH=$(uname -m)   # x86_64 / aarch64
BASE="https://github.com/omni-stack-gen/lap-releases/releases/download/$TAG"

curl -fsSLO "$BASE/lap-$TAG-linux-$ARCH"
curl -fsSLO "$BASE/SHA256SUMS"
sha256sum -c SHA256SUMS --ignore-missing       # → OK
chmod +x "lap-$TAG-linux-$ARCH"
./lap-$TAG-linux-$ARCH --version
```

---

## What's new

### v0.23.0 — x86 SoC `run` step spawn-detach

The x86-dev preview path no longer waits for you to close the slint window
before reporting the job done. After spawn, `lap` watches the binary for a
short smoke window (default 5s, override with `LAP_X86_SMOKE_SEC`); if the
binary stays alive without crashing, the run step returns immediately and
the SaaS web UI unlocks for the next prompt. The slint window keeps running
on your desktop until you replace it (submit a new prompt) or close it
manually.

**Behavior changes you may notice:**

- A new prompt SIGTERMs the previous preview window automatically (single
  instance, matching how a real device with one screen behaves). Previously
  multiple windows could pile up.
- LAP records the live preview at `~/.omnistack/x86_preview.pid`; restarting
  `lap run` cleans up an orphan preview from the previous session.
- Binary stdout/stderr go to `~/.omnistack/jobs/<job_id>/preview.{stdout,stderr}.log`
  rather than streaming through the SaaS footprint. Tail those files if you
  need to debug a binary that crashes after the smoke window.

**Removed:**

- `LAP_RUN_LIFETIME_SEC` is silently ignored — the v0.22.0 4h safety-net no
  longer applies (LAP no longer awaits child exit). To bound the smoke
  window, set `LAP_X86_SMOKE_SEC`.

**Known limitations:**

- A binary that crashes more than 5s after spawn is misjudged as healthy;
  raise `LAP_X86_SMOKE_SEC` for slow-starting GPU contexts.
- `systemctl stop lap` / `docker stop` kills the entire cgroup including the
  preview. The supported deploy form for full preview detach is direct
  `lap run` (the form `install.sh` produces).

NX5 and F1 SoC paths are unchanged.

---

## Troubleshooting

### `command not found: lap` after install

`~/.omnistack/bin` is not on your `$PATH`. Re-run the rc snippet from the
installer output, then `source ~/.bashrc` (or restart the shell). Or
invoke with the absolute path: `~/.omnistack/bin/lap --version`.

### `sha256 mismatch` during install

The download was corrupted in transit, or the release artifacts were
tampered with. Re-run `curl -fsSL .../install.sh | bash`. If it persists,
file an issue — do **not** disable verification.

### `no published release yet for this repo`

`lap self update` ran but the latest GitHub release is still in draft, or
your network is reaching the wrong endpoint. Verify the tag exists at
https://github.com/omni-stack-gen/lap-releases/releases.

### `lap run` reports `not paired`

Run `lap pair --saas-url <url> <device-code>` first. Pairing state is
persisted to `~/.omnistack/proxy.json`; you only need to do this once
per machine + SaaS pair.

### `lap self update` complains `a lap run process appears active`

Stop `lap run` first (Ctrl-C in its terminal, or `kill $(cat ~/.omnistack/run.pid)`),
then retry. Pass `--force` only if you accept that any in-flight jobs may
be abandoned.

---

## Trust model

Release artifacts are served via GitHub Releases. SHA256SUMS verification
on download protects against transit corruption. Git tag immutability and
the GitHub account boundary are the only authentication; no cosign / GPG
signing is in scope. See the source repo's docs for the full trust model.

If you're integrating `lap` into a more sensitive deployment, please
contact the maintainers about additional supply-chain hardening before
shipping.
