#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"
PACKAGER="$ROOT_DIR/scripts/package-release.sh"

require() {
    local pattern="$1"
    local file="$2"
    if ! rg -Fq -- "$pattern" "$file"; then
        echo "Missing required release security control: $pattern" >&2
        exit 1
    fi
}

forbid() {
    local pattern="$1"
    local file="$2"
    if rg -Fq -- "$pattern" "$file"; then
        echo "Forbidden release security pattern: $pattern" >&2
        exit 1
    fi
}

require "environment: release" "$WORKFLOW"
require "NOTARIZE: \"1\"" "$WORKFLOW"
require "REQUIRE_DISTRIBUTION_SIGNING: \"1\"" "$WORKFLOW"
require "APPLE_API_KEY_BASE64" "$WORKFLOW"
require "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5" "$WORKFLOW"
require "actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02" "$WORKFLOW"
require "-T /usr/bin/codesign" "$WORKFLOW"
require "gh release create" "$WORKFLOW"
require "Remove temporary signing material" "$WORKFLOW"
forbid "branches:" "$WORKFLOW"
forbid "-A -t cert" "$WORKFLOW"
forbid "softprops/action-gh-release" "$WORKFLOW"

require "REQUIRE_DISTRIBUTION_SIGNING" "$PACKAGER"
require 'xcrun stapler staple "$APP_BUNDLE"' "$PACKAGER"
require 'xcrun stapler staple "$DMG_PATH"' "$PACKAGER"
require 'xcrun stapler validate "$APP_BUNDLE"' "$PACKAGER"
require 'xcrun stapler validate "$DMG_PATH"' "$PACKAGER"
