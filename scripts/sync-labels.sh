#!/usr/bin/env bash

set -euo pipefail

ORG="paqu-io"

# name|color|description
LABELS=(
  "needs triage|c5def5|needs maintainer triage"
  "needs discussion|672028|requires design or scope discussion before implementation"
  "needs info|d876e3|more information is needed before this can progress"
  "blocked|826236|cannot progress because of another issue/dependency"

  "documentation|0075ca|improvements or additions to documentation"
  "performance|CAF58F|performance-related work"
  "breaking change|C6E69C|change affects compatibility/API expectations"

  "good first issue|7057FF|issue good for newcomers to tackle"
  "help wanted|008672|external contributions are welcome"
)

PRUNE=false

if [[ "${1:-}" == "--prune" ]]; then
  PRUNE=true
fi

# Labels we no longer want.
RETIRED_LABELS=(
  "can't reproduce"
  "duplicate"
  "good to have"
  "hotfix"
  "invalid"
  "security breach"
  "wait for response"
  "wait for review"
  "wait for votes"
  "website"
  "wiki"
  "won't do"
  "wont do"
)

echo "Discovering public form0 repositories in ${ORG}..."

mapfile -t REPOS < <(
  gh repo list "$ORG" \
    --visibility public \
    --limit 200 \
    --json name,isArchived \
    --jq '.[] |
      select(.isArchived == false) |
      select(.name | startswith("form0-")) |
      .name'
)

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "No public form0-* repositories found."
  exit 1
fi

echo "Found ${#REPOS[@]} repositories:"
printf '  - %s\n' "${REPOS[@]}"
echo

for repo in "${REPOS[@]}"; do
  full_repo="${ORG}/${repo}"

  echo "→ ${full_repo}"

  # One-time migrations that preserve existing issue associations.
  if gh label list --repo "$full_repo" --json name --jq '.[].name' |
       grep -Fxq "for discussion"; then

    if ! gh label list --repo "$full_repo" --json name --jq '.[].name' |
         grep -Fxq "needs discussion"; then
      gh label edit "for discussion" \
        --repo "$full_repo" \
        --name "needs discussion" \
        --description "requires design or scope discussion before implementation"
    fi
  fi

  if gh label list --repo "$full_repo" --json name --jq '.[].name' |
       grep -Fxq "question"; then

    if ! gh label list --repo "$full_repo" --json name --jq '.[].name' |
         grep -Fxq "needs info"; then
      gh label edit "question" \
        --repo "$full_repo" \
        --name "needs info" \
        --description "more information is needed before this can progress"
    fi
  fi

  # Ensure canonical labels exist and have consistent metadata.
  for definition in "${LABELS[@]}"; do
    IFS='|' read -r name color description <<< "$definition"

    gh label create "$name" \
      --repo "$full_repo" \
      --color "$color" \
      --description "$description" \
      --force
  done

  # Optional destructive cleanup.
  if [[ "$PRUNE" == true ]]; then
    for label in "${RETIRED_LABELS[@]}"; do
      gh label delete "$label" \
        --repo "$full_repo" \
        --yes 2>/dev/null || true
    done
  fi

  echo
done

echo "✓ Label synchronization complete."
