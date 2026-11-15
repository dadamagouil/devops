#!/usr/bin/env bash
# Publishes a development build (APK...) in a pre-release updated IN PLACE.
# The release is never deleted, so a failure half-way does not remove the last working build.
# Official releases (vX.Y.Z) are created elsewhere, by hand.
#
# Environment (all set by action.yml):
#   GH_TOKEN, REPO, GITHUB_SHA   standard GitHub values
#   TAG                          pre-release tag (default dev-latest)
#   SOURCE_FILE                  built file to publish
#   ASSET_NAME                   name of the file on the release
#   BUILD, BRANCH                labels written in the title and notes
#   MOVE_TAG                     "true": move the tag to this commit. A moved tag needs a personal access token
#                                with Contents + Workflows write access (the automatic token cannot move a tag
#                                to a commit that changed .github/workflows); "false": the tag stays where it was
#                                created and the automatic token is enough.
# Run from the repository root.
set -euo pipefail

TAG=${TAG:-dev-latest}
MOVE_TAG=${MOVE_TAG:-false}
NOW=$(date -u '+%Y-%m-%d %H:%M UTC')
TITLE="Android $BUILD (development) - $NOW"

[ -f "$SOURCE_FILE" ] || { echo "::error::Build file not found: $SOURCE_FILE"; exit 1; }
cp "$SOURCE_FILE" "$ASSET_NAME"
printf 'Build: %s\nEnvironment: dev\nBranch: %s\nCommit: %s\nDate: %s\n\nAutomatic development build (pre-release). Install the file below on Android.\n' \
  "$BUILD" "${BRANCH:-unknown}" "$GITHUB_SHA" "$NOW" > notes.txt

move_tag() {
  [ "$MOVE_TAG" = true ] && git push --force origin "$GITHUB_SHA:refs/tags/$TAG"
  return 0
}

# GitHub shows the date of the FIRST publication: switch to draft and publish again so the displayed date
# is the one of this build (the file and the tag do not move).
refresh_date() {
  echo "==> Refreshing the date of $TAG"
  if ! gh release edit "$TAG" --repo "$REPO" --draft=true; then
    echo "::warning::Date of $TAG not refreshed (switching to draft was refused)."
    return 0
  fi
  for attempt in 1 2 3 4 5; do
    if gh release edit "$TAG" --repo "$REPO" --draft=false --prerelease --latest=false; then
      return 0
    fi
    echo "Could not publish again (attempt $attempt), retrying..."
    sleep 5
  done
  echo "::error::$TAG stayed a draft: publish it by hand (Releases -> Edit -> Publish)."
  return 1
}

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "==> Updating $TAG ($BUILD)"
  gh release upload "$TAG" "$ASSET_NAME" --clobber --repo "$REPO"
  # Keep only the file of this build (remove anything left by earlier versions).
  for asset in $(gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name'); do
    [ "$asset" = "$ASSET_NAME" ] || gh release delete-asset "$TAG" "$asset" --yes --repo "$REPO"
  done
  move_tag
  gh release edit "$TAG" --repo "$REPO" --title "$TITLE" --notes-file notes.txt --prerelease --latest=false
  refresh_date
else
  echo "==> First publication of $TAG ($BUILD)"
  move_tag
  gh release create "$TAG" "$ASSET_NAME" --repo "$REPO" --target "$GITHUB_SHA" \
    --title "$TITLE" --notes-file notes.txt --prerelease
fi

echo "==> Done: https://github.com/$REPO/releases/tag/$TAG"
{
  echo "### Development build ($BUILD) - $NOW"
  echo "Branch: \`${BRANCH:-unknown}\` · Commit: \`${GITHUB_SHA:0:7}\`"
  echo "[Download $ASSET_NAME](https://github.com/$REPO/releases/download/$TAG/$ASSET_NAME)"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
