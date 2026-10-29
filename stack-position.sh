#!/usr/bin/env bash
#
# Writes skip=true to $GITHUB_OUTPUT when an open PR is based on this PR's head branch, its head
# contains this PR's head commit, and this PR has no ci/run-full label. Every other path writes
# skip=false, so a broken lookup runs CI.
#
# Requires GH_TOKEN, GH_REPO, HEAD_REF, HEAD_SHA and PR_NUMBER from action.yml.

set -euo pipefail

WAIT_SECONDS=60
LABEL="ci/run-full"

run_ci() {
  echo "skip=false" >>"$GITHUB_OUTPUT"
  exit 0
}

# gt submit pushes a stack bottom-up and parks each PR on graphite-base/N while it pushes. The PR
# above this one may not exist or point here yet when this PR's event fires.
sleep "$WAIT_SECONDS"

# A ci/ branch is a bot's fix PR on this branch. It never runs CI, so it can't be the top.
if ! candidates=$(gh pr list --state open --base "$HEAD_REF" --json number,headRefName,headRefOid \
  --jq '.[] | select(.headRefName | startswith("ci/") | not) | "\(.number) \(.headRefOid)"'); then
  echo "::warning title=stack-position::gh pr list failed, running CI"
  run_ci
fi

# A PR above that hasn't been restacked onto this push won't test it. Neither will a fork that
# branched off an older commit of this PR.
upstack=""
while read -r number sha; do
  [[ -n "$number" ]] || continue
  if ! status=$(gh api "repos/$GH_REPO/compare/$HEAD_SHA...$sha" --jq .status); then
    echo "::warning title=stack-position::Comparing with #$number failed, not counting it"
    continue
  fi
  if [[ "$status" == "ahead" || "$status" == "identical" ]]; then
    upstack+="${upstack:+, }#$number"
  else
    echo "#$number is stacked on this PR but doesn't contain $HEAD_SHA ($status)"
  fi
done <<<"$candidates"

if [[ -z "$upstack" ]]; then
  echo "No open PR stacked on this one contains its head, running CI"
  run_ci
fi

if ! labels=$(gh pr view "$PR_NUMBER" --json labels --jq '.labels[].name'); then
  echo "::warning title=stack-position::gh pr view failed, running CI"
  run_ci
fi

if grep -qxF "$LABEL" <<<"$labels"; then
  echo "::notice title=stack-position::$LABEL is set, running CI although $upstack is stacked on this PR"
  run_ci
fi

message="Skipped: $upstack is stacked on this PR, so CI runs there. To run it here, add the \`$LABEL\` label and re-run this workflow."
echo "::notice title=CI skipped below the top of the stack::$message"
echo "$message" >>"$GITHUB_STEP_SUMMARY"
echo "skip=true" >>"$GITHUB_OUTPUT"
