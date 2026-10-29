#!/bin/bash

set -euo pipefail

BIN="${1:-}"
if [ -z "$BIN" ]; then
    for cand in \
        ".build/release/MacClean" \
        ".build/debug/MacClean" \
        "/Applications/Mac Sai.app/Contents/MacOS/MacClean"; do
        if [ -f "$cand" ]; then BIN="$cand"; break; fi
    done
fi
if [ -z "$BIN" ] || [ ! -f "$BIN" ]; then
    echo "::error::check-network-surface: no binary found to inspect (pass a path)"
    exit 1
fi
echo "Inspecting network surface of: $BIN"

SYMS="$(nm -u "$BIN" 2>/dev/null || true)"
STRS="$(strings -a "$BIN" 2>/dev/null || true)"

fail=0

BANNED_SYMBOLS='NWConnection|NWBrowser|nw_connection|nw_endpoint|CFSocket|CFStreamCreatePairWithSocketToHost|CFReadStreamCreate|CFWriteStreamCreate'
sym_hits="$(grep -iE "$BANNED_SYMBOLS" <<<"$SYMS" | sort -u || true)"
if [ -n "$sym_hits" ]; then
    echo "::error::Unexpected low-level networking symbols:"
    echo "$sym_hits"
    fail=1
fi

BANNED_HOSTS='sentry\.io|mixpanel|firebase|firebaseio|google-analytics|googletagmanager|doubleclick|segment\.(io|com)|amplitude|bugsnag|crashlytics|datadoghq|posthog|appcenter\.ms|adjust\.com|appsflyer|flurry|umeng'
host_hits="$(grep -iE "$BANNED_HOSTS" <<<"$STRS" | sort -u || true)"
if [ -n "$host_hits" ]; then
    echo "::error::Tracker/analytics endpoint or SDK marker found:"
    echo "$host_hits"
    fail=1
fi

for endpoint in \
    "api.github.com/repos/iliyami/MacSai/releases/latest" \
    "formulae.brew.sh/api/cask/mac-sai.json"; do
    if ! grep -qF "$endpoint" <<<"$STRS"; then
        echo "::warning::expected update endpoint not found in binary: $endpoint"
    fi
done

echo "--- Networking symbols imported (expect only NSURLSession) ---"
grep -iE 'URLSession|URLConnection|CFNetwork|NWConnection|CFSocket|CFStream' <<<"$SYMS" | sort -u || echo "(none)"
echo "--- URLs compiled into the binary ---"
grep -iE 'https?://' <<<"$STRS" | sort -u || echo "(none)"

if [ "$fail" -ne 0 ]; then
    echo "::error::Network-surface check FAILED (see above)."
    exit 1
fi
echo "Network-surface check passed: only URLSession, only the disclosed endpoints."
