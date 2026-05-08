# lap-releases

Pre-built Linux binaries for the `lap` (Local Agent Proxy) CLI. The source
code lives in a separate (currently private) repository under the same
GitHub organization; this repo only hosts release artifacts so they can be
fetched without authentication.

## Install

Linux x86_64 / aarch64:

```bash
curl -fsSL https://raw.githubusercontent.com/omni-stack-gen/lap-releases/main/install.sh | bash
```

Pin a specific version:

```bash
LAP_VERSION=v0.22.0 curl -fsSL https://raw.githubusercontent.com/omni-stack-gen/lap-releases/main/install.sh | bash
```

After install:

```bash
lap pair --saas-url <your-saas-url> <device-code>
lap run
```

Upgrade in place:

```bash
lap self update
```

## What's included per release

Each tag `vX.Y.Z` ships:

- `lap-vX.Y.Z-linux-x86_64` — onefile binary built on `manylinux_2_28_x86_64`
  (glibc 2.28 baseline → runs on RHEL 8+, Debian 11+, Ubuntu 20.04+, modern Fedora)
- `lap-vX.Y.Z-linux-aarch64` — same, for ARM64
- `SHA256SUMS` — sha256 hashes of both binaries; install.sh verifies these
  before placing the binary in `~/.omnistack/bin/lap`

## Trust model

Release artifacts are served via GitHub Releases. SHA256SUMS verification
on download protects against transit corruption. Git tag immutability and
the GitHub account boundary are the only authentication; no cosign / GPG
signing is in scope. See the source repo's docs for the full trust model.
