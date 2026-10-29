#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Mac Sai"
APP_BUNDLE=".build/dmg/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
DIRTY=$(git status --porcelain 2>/dev/null | head -1 | grep -q . && echo " + uncommitted changes" || true)
echo "=== Dev install: building current checkout [${BRANCH}${DIRTY}] v$(tr -d '[:space:]' < VERSION) ($(uname -m), ad-hoc signed) ==="
BUILD_ARCHS="--arch $(uname -m)" ./scripts/build-dmg.sh --app-only

DEVID=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')
if [ -n "${DEVID}" ]; then
    echo "Re-signing with: ${DEVID}"
    if codesign --force --deep --sign "${DEVID}" "${APP_BUNDLE}" >/dev/null 2>&1; then
        echo "  → stable signature applied (FDA persists across dev builds)"
    else
        echo "  → re-sign failed; staying ad-hoc (FDA will re-prompt)"
    fi
else
    echo "No Developer ID Application identity found; ad-hoc signed (FDA re-prompts each build)."
fi

osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
pkill -x MacCleanMenu 2>/dev/null || true
pkill -x MacClean 2>/dev/null || true
sleep 1

echo "Installing to ${DEST}..."
rm -rf "${DEST}"
ditto "${APP_BUNDLE}" "${DEST}"

echo "Launching..."
open "${DEST}"

echo ""
echo "Done. Notes:"
echo "  - This build is ad-hoc signed; its signature differs from the notarized"
echo "    release, so macOS may ask you to re-grant Full Disk Access"
echo "    (System Settings -> Privacy & Security -> Full Disk Access)."
echo "  - A later 'brew upgrade --cask mac-sai' will overwrite this dev build."
