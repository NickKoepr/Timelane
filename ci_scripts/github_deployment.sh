#!/bin/sh
# Shared helpers for reporting Xcode Cloud archives as GitHub deployments.
# Sourced by ci_pre_xcodebuild.sh and ci_post_xcodebuild.sh.
# Needs the secret environment variable GITHUB_TOKEN (fine-grained token,
# Deployments: read & write). Every failure is logged and ignored, so GitHub
# can never break a build.

GITHUB_REPOSITORY="NickKoepr/Timelane"
GITHUB_ENVIRONMENT="App Store Connect"
DEPLOYMENT_ID_FILE="${CI_DERIVED_DATA_PATH:-/tmp}/github-deployment-id"

# Reports only for archives that have a token.
github_deployment_enabled() {
  [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ] || return 1
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "GITHUB_TOKEN not set; skipping GitHub deployment."
    return 1
  fi
}

# github_api METHOD PATH JSON -> prints the response body, fails on HTTP errors.
github_api() {
  curl --silent --show-error --fail-with-body --max-time 30 \
    -X "$1" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY$2" \
    -d "$3"
}

# Creates a deployment for the tag and stores its id for the post script.
github_deployment_create() {
  # required_contexts: [] because Xcode Cloud's own check is still pending.
  body="{\"ref\":\"$CI_TAG\",\"environment\":\"$GITHUB_ENVIRONMENT\",\"auto_merge\":false,\"required_contexts\":[],\"production_environment\":true,\"description\":\"Xcode Cloud build ${CI_BUILD_NUMBER:-}\"}"
  if ! response=$(github_api POST /deployments "$body"); then
    echo "warning: could not create GitHub deployment: $response"
    return 0
  fi
  id=$(printf '%s' "$response" | plutil -extract id raw -o - - 2>/dev/null) || {
    echo "warning: unexpected GitHub response: $response"
    return 0
  }
  echo "$id" > "$DEPLOYMENT_ID_FILE"
  echo "Created GitHub deployment $id"
  github_deployment_status in_progress
}

# github_deployment_status STATE (in_progress, success, failure, error)
github_deployment_status() {
  [ -f "$DEPLOYMENT_ID_FILE" ] || { echo "No GitHub deployment to update."; return 0; }
  id=$(cat "$DEPLOYMENT_ID_FILE")
  log_url=""
  [ -n "${CI_BUILD_URL:-}" ] && log_url=",\"log_url\":\"$CI_BUILD_URL\""
  body="{\"state\":\"$1\",\"description\":\"Xcode Cloud build ${CI_BUILD_NUMBER:-}\"$log_url}"
  if github_api POST "/deployments/$id/statuses" "$body" > /dev/null; then
    echo "GitHub deployment $id: $1"
  else
    echo "warning: could not update GitHub deployment $id"
  fi
  return 0
}
