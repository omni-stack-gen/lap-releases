#!/usr/bin/env bash
# lap installer — download a release binary from GitHub, verify SHA256, install
# under ~/.omnistack/bin/. Linux-only (x86_64 / aarch64).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/omni-stack-gen/lap-releases/main/install.sh | bash
#
# Env overrides:
#   LAP_VERSION=v0.23.0          pin a specific tag (default: latest)
#   LAP_INSTALL_DIR=/path        custom install dir (default: ~/.omnistack/bin)
#   LAP_ALLOW_SYSTEM_DIR=1       allow LAP_INSTALL_DIR outside $HOME (else refuse)
#
# Plan ref: docs/2026-05-07-lap-binary-distribution-plan.zh.md (Unit 5).

set -euo pipefail

REPO="omni-stack-gen/lap-releases"
INSTALL_DIR="${LAP_INSTALL_DIR:-$HOME/.omnistack/bin}"
ALLOW_SYS="${LAP_ALLOW_SYSTEM_DIR:-0}"
PIN_VERSION="${LAP_VERSION:-}"

# 1. OS / arch detection (Linux only; uname -m output ∈ {x86_64, aarch64})
if [ "$(uname -s)" != "Linux" ]; then
    echo "ERROR: Linux only (detected $(uname -s))" >&2
    exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|aarch64) ;;
    *) echo "ERROR: unsupported arch '$ARCH' (linux-x86_64 / linux-aarch64 only)" >&2; exit 1;;
esac

# 2. Validate INSTALL_DIR — must be absolute, and under $HOME unless explicitly
#    permitted via LAP_ALLOW_SYSTEM_DIR=1
case "$INSTALL_DIR" in
    "$HOME"/*) ;;
    /*)
        if [ "$ALLOW_SYS" != "1" ]; then
            echo "ERROR: LAP_INSTALL_DIR='$INSTALL_DIR' is outside \$HOME." >&2
            echo "       Set LAP_ALLOW_SYSTEM_DIR=1 to override." >&2
            exit 1
        fi
        ;;
    *) echo "ERROR: LAP_INSTALL_DIR must be an absolute path (got '$INSTALL_DIR')" >&2; exit 1;;
esac

# 3. Resolve target tag (LAP_VERSION pin OR GitHub API latest)
if [ -n "$PIN_VERSION" ]; then
    TAG="$PIN_VERSION"
else
    TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -m1 '"tag_name"' \
        | cut -d'"' -f4 || true)"
    if [ -z "$TAG" ]; then
        echo "ERROR: cannot fetch latest release tag from GitHub API" >&2
        echo "       (no published release yet, or network/rate-limit issue)" >&2
        exit 1
    fi
fi

# 4. Download binary + SHA256SUMS to a private tmpdir; cleanup on exit
BIN_NAME="lap-$TAG-linux-$ARCH"
BASE="https://github.com/$REPO/releases/download/$TAG"
TMPDIR="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR"' EXIT

echo "[lap install] downloading $BIN_NAME ($TAG)..." >&2
curl -fsSL -o "$TMPDIR/$BIN_NAME" "$BASE/$BIN_NAME" \
    || { echo "ERROR: failed to download $BASE/$BIN_NAME" >&2; exit 1; }
curl -fsSL -o "$TMPDIR/SHA256SUMS"  "$BASE/SHA256SUMS" \
    || { echo "ERROR: failed to download $BASE/SHA256SUMS" >&2; exit 1; }

# 5. Verify sha256 — abort on mismatch (do NOT install a corrupt binary).
#    Normalize line endings (defensive: SHA256SUMS served via a CRLF proxy
#    would otherwise cause $-anchor to never match → confusing fail-closed
#    "sha256 mismatch" error). Use grep -F (fixed-string) so dots in the
#    binary name aren't interpreted as regex wildcards.
echo "[lap install] verifying sha256..." >&2
tr -d '\r' < "$TMPDIR/SHA256SUMS" > "$TMPDIR/SHA256SUMS.norm"
matched_lines="$(grep -F " $BIN_NAME" "$TMPDIR/SHA256SUMS.norm" | grep -E " $BIN_NAME\$" || true)"
if [ -z "$matched_lines" ]; then
    echo "ERROR: SHA256SUMS contains no entry for $BIN_NAME" >&2
    exit 1
fi
( cd "$TMPDIR" && echo "$matched_lines" | sha256sum -c - ) \
    || { echo "ERROR: sha256 mismatch (download corrupt or release tampered)" >&2; exit 1; }

# 6. Install — stage in INSTALL_DIR (NOT /tmp) so the final mv is an atomic
#    same-fs rename even when $TMPDIR (/tmp) is on a different filesystem
#    from $HOME.
mkdir -p -m 0700 "$INSTALL_DIR"
STAGE="$INSTALL_DIR/.lap.tmp.$$"
trap 'rm -rf -- "$TMPDIR" "$STAGE"' EXIT
cp -f "$TMPDIR/$BIN_NAME" "$STAGE"
chmod 0755 "$STAGE"
mv -f "$STAGE" "$INSTALL_DIR/lap"

echo "[OK] lap $TAG installed to $INSTALL_DIR/lap" >&2

# 7. PATH guidance — detect whether INSTALL_DIR is on PATH and emit
#    appropriate next-step instructions
case ":$PATH:" in
    *":$INSTALL_DIR:"*)
        echo "" >&2
        echo "Next:" >&2
        echo "  lap pair --saas-url <url> <device_code>" >&2
        echo "  lap run" >&2
        ;;
    *)
        echo "" >&2
        echo "[ACTION REQUIRED] $INSTALL_DIR is NOT on your PATH." >&2
        echo "Add this to your shell rc and reopen the shell, then try lap again:" >&2
        case "$(basename "${SHELL:-/bin/bash}")" in
            bash) echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc" >&2;;
            zsh)  echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc" >&2;;
            fish) echo "  fish_add_path '$INSTALL_DIR'" >&2;;
            *)    echo "  export PATH=\"$INSTALL_DIR:\$PATH\"  # add to your shell rc" >&2;;
        esac
        echo "" >&2
        echo "Or invoke lap with its absolute path:" >&2
        echo "  $INSTALL_DIR/lap --version" >&2
        ;;
esac

echo "" >&2
echo "Onboarding: https://github.com/$REPO/blob/main/docs/lap-onboarding.zh.md" >&2
