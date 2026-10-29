#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <staging-dir>" >&2
    exit 2
fi

STAGING="$1"

if [[ ! -d "$STAGING" ]]; then
    echo "error: staging dir does not exist: $STAGING" >&2
    exit 1
fi

rm -f "${STAGING}/entitlements.plist"
rm -f "${STAGING}"/*-notarize.zip

rm -rf "${STAGING}/Applications"
ln -s /Applications "${STAGING}/Applications"
