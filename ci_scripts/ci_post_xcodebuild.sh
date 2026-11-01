#!/bin/sh
# Runs in Xcode Cloud after xcodebuild: marks the GitHub deployment for this
# archive as succeeded or failed. The upload to App Store Connect happens later.
set -u

. "$(dirname "$0")/github_deployment.sh"
if github_deployment_enabled; then
  if [ "${CI_XCODEBUILD_EXIT_CODE:-1}" = "0" ]; then
    github_deployment_status success
  else
    github_deployment_status failure
  fi
fi
exit 0
