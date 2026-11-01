#!/bin/sh
# Runs in Xcode Cloud before xcodebuild.
# Sets MARKETING_VERSION from the git tag (v1.7 -> 1.7). App Store builds must
# come from a tag, so a build without one stops here instead of failing the upload.
set -eu

if [ -z "${CI_TAG:-}" ]; then
  echo "error: no git tag; start this workflow from a version tag like v1.7"
  exit 1
fi

VERSION="${CI_TAG#v}"
case "$VERSION" in
  *[!0-9.]*|"") echo "error: tag '$CI_TAG' is not a version like v1.7 or v1.7.1"; exit 1 ;;
esac

sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/" \
  "$CI_PRIMARY_REPOSITORY_PATH/Timelane.xcodeproj/project.pbxproj"
echo "MARKETING_VERSION set to $VERSION"
