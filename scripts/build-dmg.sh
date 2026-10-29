#!/bin/bash

set -euo pipefail

APP_NAME="Mac Sai"
BUNDLE_ID="com.macclean.app"
VERSION="${VERSION:-$(cat VERSION 2>/dev/null | tr -d '[:space:]' || echo '1.0.0')}"
DMG_DIR=".build/dmg"
DMG_NAME="MacSai-${VERSION}.dmg"

APP_ONLY=false
if [[ "${1:-}" == "--app-only" ]]; then
    APP_ONLY=true
fi
NOTARIZE=false
SIGNING_IDENTITY="-"
if [[ "${1:-}" == "--notarize" ]]; then
    NOTARIZE=true
    if [[ -z "${APPLE_DEVELOPER_ID:-}" ]]; then
        echo "ERROR: --notarize requires APPLE_DEVELOPER_ID env var"
        echo "Example: export APPLE_DEVELOPER_ID='Developer ID Application: John Doe (ABC123XYZ)'"
        exit 1
    fi
    if [[ -z "${NOTARY_PROFILE:-}" ]]; then
        echo "ERROR: --notarize requires NOTARY_PROFILE env var"
        echo "Set it up first: xcrun notarytool store-credentials 'MacClean' --apple-id YOU@example.com --team-id TEAMID"
        exit 1
    fi
    SIGNING_IDENTITY="$APPLE_DEVELOPER_ID"
fi

echo "=== Building Mac Sai v${VERSION} ==="
echo "Signing identity: $SIGNING_IDENTITY"
echo "Notarize: $NOTARIZE"
echo ""

BUILD_ARCHS="${BUILD_ARCHS:---arch arm64 --arch x86_64}"
echo "[1/7] Building release binaries (${BUILD_ARCHS})..."
swift build -c release ${BUILD_ARCHS} --product MacClean
swift build -c release ${BUILD_ARCHS} --product MacCleanMenu
BUILD_DIR=$(swift build -c release ${BUILD_ARCHS} --product MacClean --show-bin-path)
echo "  → Binaries: ${BUILD_DIR}"

echo "[2/7] Creating app bundle..."
APP_BUNDLE="${DMG_DIR}/${APP_NAME}.app"
rm -rf "${DMG_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/MacClean" "${APP_BUNDLE}/Contents/MacOS/"

cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
        <string>de</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>fr</string>
        <string>it</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>MacClean</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.macclean.deeplink</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>macclean</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
fi
if [ -d "Sources/MacCleanKit/Resources" ]; then
    cp -R Sources/MacCleanKit/Resources/*.lproj "${APP_BUNDLE}/Contents/Resources/"
fi

echo "[2.5/7] Bundling MacCleanMenu widget..."
MENU_APP="${APP_BUNDLE}/Contents/Library/LoginItems/MacCleanMenu.app"
mkdir -p "${MENU_APP}/Contents/MacOS"
mkdir -p "${MENU_APP}/Contents/Resources"

cp "${BUILD_DIR}/MacCleanMenu" "${MENU_APP}/Contents/MacOS/"

cat > "${MENU_APP}/Contents/Info.plist" << MENU_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
        <string>de</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>fr</string>
        <string>it</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>MacCleanMenu</string>
    <key>CFBundleIdentifier</key>
    <string>com.macclean.menu</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Mac Sai Menu</string>
    <key>CFBundleDisplayName</key>
    <string>Mac Sai Menu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
MENU_PLIST

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${MENU_APP}/Contents/Resources/"
fi
if [ -d "Sources/MacCleanKit/Resources" ]; then
    cp -R Sources/MacCleanKit/Resources/*.lproj "${MENU_APP}/Contents/Resources/"
fi

echo "[3/7] Creating entitlements..."
ENTITLEMENTS_FILE=".build/entitlements.plist"
mkdir -p .build
cat > "${ENTITLEMENTS_FILE}" << ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

echo "[4/7] Signing app bundle..."
if [[ "$NOTARIZE" == "true" ]]; then
    codesign --force --deep --options runtime \
        --entitlements "${ENTITLEMENTS_FILE}" \
        --sign "$SIGNING_IDENTITY" \
        --timestamp \
        "${APP_BUNDLE}"
    echo "  → Signed with Developer ID + hardened runtime"
else
    codesign --force --deep --sign "$SIGNING_IDENTITY" "${APP_BUNDLE}"
    echo "  → Ad-hoc signed (no Developer ID provided)"
fi

codesign --verify --verbose=1 "${APP_BUNDLE}" 2>&1 | head -3

if [[ "$APP_ONLY" == "true" ]]; then
    echo ""
    echo "=== App bundle ready (skipped DMG/notarization) ==="
    echo "App: ${APP_BUNDLE}"
    exit 0
fi

if [[ "$NOTARIZE" == "true" ]]; then
    echo "[5/7] Notarizing + stapling the app bundle..."
    APP_ZIP=".build/${APP_NAME}-notarize.zip"
    ditto -c -k --keepParent "${APP_BUNDLE}" "${APP_ZIP}"
    xcrun notarytool submit "${APP_ZIP}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait
    rm -f "${APP_ZIP}"
    xcrun stapler staple "${APP_BUNDLE}"
    xcrun stapler validate "${APP_BUNDLE}"
    echo "  → App notarized and stapled (verifies offline)"
fi

echo "[6/7] Creating DMG..."
bash "$(dirname "$0")/prepare-dmg-staging.sh" "${DMG_DIR}"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    ".build/${DMG_NAME}" > /dev/null

if [[ "$NOTARIZE" == "true" ]]; then
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp ".build/${DMG_NAME}"
    echo "  → DMG signed with Developer ID"
fi

if [[ "$NOTARIZE" == "true" ]]; then
    echo "[7/7] Notarizing DMG..."
    xcrun notarytool submit ".build/${DMG_NAME}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait
    xcrun stapler staple ".build/${DMG_NAME}"
    xcrun stapler validate ".build/${DMG_NAME}"
    echo "  → Notarization complete (DMG stapled; app inside stapled too)"
else
    echo "[7/7] Skipping notarization (no --notarize flag)"
fi

SHA256=$(shasum -a 256 ".build/${DMG_NAME}" | awk '{print $1}')

echo ""
echo "=== Build complete ==="
echo "DMG:    .build/${DMG_NAME}"
echo "Size:   $(du -h ".build/${DMG_NAME}" | cut -f1)"
echo "SHA256: ${SHA256}"
