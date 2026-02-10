#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Build XCFramework for SwiftMockServer
# ─────────────────────────────────────────────

SCHEME="SwiftMockServer"
FRAMEWORK_NAME="SwiftMockServer"
BUILD_DIR="$(pwd)/build"
DERIVED_DATA="${BUILD_DIR}/deriveddata"
XCFRAMEWORK_PATH="${BUILD_DIR}/${FRAMEWORK_NAME}.xcframework"
ZIP_PATH="${BUILD_DIR}/${FRAMEWORK_NAME}.xcframework.zip"

# Parallel arrays: destination and the products subfolder (bash 3.2 compatible)
DESTINATIONS=(
    "generic/platform=iOS"
    "generic/platform=iOS Simulator"
    "generic/platform=macOS"
    "generic/platform=tvOS"
    "generic/platform=tvOS Simulator"
    "generic/platform=watchOS"
    "generic/platform=watchOS Simulator"
)
LABELS=(
    iphoneos
    iphonesimulator
    macosx
    appletvos
    appletvsimulator
    watchos
    watchsimulator
)

# ─────────────────────────────────────────────
# Clean previous build
# ─────────────────────────────────────────────

echo "▸ Cleaning previous build artifacts…"
rm -rf "${BUILD_DIR}"

# ─────────────────────────────────────────────
# Build each platform
# ─────────────────────────────────────────────

for i in "${!DESTINATIONS[@]}"; do
    destination="${DESTINATIONS[$i]}"
    label="${LABELS[$i]}"
    echo "▸ Building ${label}…"
    xcodebuild build \
        -scheme "${SCHEME}" \
        -configuration Release \
        -destination "${destination}" \
        -derivedDataPath "${DERIVED_DATA}/${label}" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
        -quiet
done

# ─────────────────────────────────────────────
# Assemble XCFramework
# ─────────────────────────────────────────────

echo "▸ Creating XCFramework…"

FRAMEWORK_ARGS=()
for i in "${!LABELS[@]}"; do
    label="${LABELS[$i]}"
    framework_path=$(find "${DERIVED_DATA}/${label}" -name "${FRAMEWORK_NAME}.framework" -type d | head -1)
    if [ -z "${framework_path}" ]; then
        echo "error: framework not found for ${label}" >&2
        echo "Build contents:" >&2
        find "${DERIVED_DATA}/${label}/Build/Products" -maxdepth 4 >&2 || true
        exit 1
    fi
    echo "  ${label}: ${framework_path}"
    FRAMEWORK_ARGS+=(-framework "${framework_path}")
done

xcodebuild -create-xcframework \
    "${FRAMEWORK_ARGS[@]}" \
    -output "${XCFRAMEWORK_PATH}"

# ─────────────────────────────────────────────
# Zip (deterministic) + checksum
# ─────────────────────────────────────────────

echo "▸ Creating zip archive…"
ditto -c -k --sequesterRsrc --keepParent "${XCFRAMEWORK_PATH}" "${ZIP_PATH}"

echo "▸ Computing checksum…"
CHECKSUM=$(swift package compute-checksum "${ZIP_PATH}")

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════"
echo "  XCFramework built successfully!"
echo "═══════════════════════════════════════════"
echo ""
echo "  Zip:      ${ZIP_PATH}"
echo "  Checksum: ${CHECKSUM}"
echo ""
echo "  Next steps:"
echo "    1. Upload the zip to the GitHub release (tag 1.1.0)"
echo "    2. Update Package.swift checksum:"
echo "       checksum: \"${CHECKSUM}\""
echo ""
