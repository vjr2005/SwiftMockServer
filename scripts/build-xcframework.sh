#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Build XCFramework for SwiftMockServer
# ─────────────────────────────────────────────

SCHEME="SwiftMockServer"
FRAMEWORK_NAME="SwiftMockServer"
BUILD_DIR="$(pwd)/build"
ARCHIVES_DIR="${BUILD_DIR}/archives"
XCFRAMEWORK_PATH="${BUILD_DIR}/${FRAMEWORK_NAME}.xcframework"
ZIP_PATH="${BUILD_DIR}/${FRAMEWORK_NAME}.xcframework.zip"

COMMON_FLAGS=(
    -scheme "${SCHEME}"
    -configuration Release
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    SKIP_INSTALL=NO
    SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO
)

PLATFORMS=(
    "iphoneos"
    "iphonesimulator"
    "macosx"
    "appletvos"
    "appletvsimulator"
    "watchos"
    "watchsimulator"
)

# ─────────────────────────────────────────────
# Clean previous build
# ─────────────────────────────────────────────

echo "▸ Cleaning previous build artifacts…"
rm -rf "${BUILD_DIR}"
mkdir -p "${ARCHIVES_DIR}"

# ─────────────────────────────────────────────
# Archive each platform
# ─────────────────────────────────────────────

for sdk in "${PLATFORMS[@]}"; do
    archive_path="${ARCHIVES_DIR}/${FRAMEWORK_NAME}-${sdk}.xcarchive"
    echo "▸ Archiving ${sdk}…"
    xcodebuild archive \
        "${COMMON_FLAGS[@]}" \
        -sdk "${sdk}" \
        -archivePath "${archive_path}" \
        -quiet
done

# ─────────────────────────────────────────────
# Assemble XCFramework
# ─────────────────────────────────────────────

echo "▸ Creating XCFramework…"

FRAMEWORK_ARGS=()
for sdk in "${PLATFORMS[@]}"; do
    archive_path="${ARCHIVES_DIR}/${FRAMEWORK_NAME}-${sdk}.xcarchive"
    framework_path="${archive_path}/Products/usr/local/lib/${FRAMEWORK_NAME}.framework"
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
