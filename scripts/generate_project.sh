#!/bin/sh
# Regenerates KyleOS.xcodeproj from project.yml via XcodeGen, then
# downgrades the project file format to one Xcode 15.4 can open.
#
# XcodeGen's bundled default objectVersion targets a newer Xcode than
# the pinned Intel-Mac toolchain (see docs/TECHNICAL_ARCHITECTURE.md
# 15.3 amendment) — without this step, `xcodebuild` fails with
# "future Xcode project file format" after every regenerate.
set -e
cd "$(dirname "$0")/.."
xcodegen generate
sed -i '' 's/objectVersion = 77;/objectVersion = 56;/' KyleOS.xcodeproj/project.pbxproj
echo "Project regenerated at KyleOS.xcodeproj (objectVersion pinned to 56 for Xcode 15.4 compatibility)."
