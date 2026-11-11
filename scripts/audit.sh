#!/usr/bin/env bash
# Lists the org's repos that the required zizmor check doesn't cover yet have findings,
# and repos with dependencies but no dependabot.yml. Needs gh (logged in), jq and uvx.
set -euo pipefail

org="${1:-Mozilla-Data-Collective}"
here="$(cd "$(dirname "$0")/.." && pwd)"
workflow="$here/.github/workflows/zizmor.yml"

version="$(sed -n 's/^ *version: "\(.*\)"$/\1/p' "$workflow")"
config="$(mktemp)"
trap 'rm -f "$config"' EXIT
sed -n "/<<'EOF'/,/^ *EOF$/p" "$workflow" | sed '1d;$d' | sed 's/^          //' > "$config"
[ -n "$version" ] && [ -s "$config" ] || { echo "could not read zizmor's version or config from $workflow" >&2; exit 1; }

GH_TOKEN="$(gh auth token)"
export GH_TOKEN

echo "# Audit of $org, $(date -u +%Y-%m-%d), zizmor $version"
echo
echo "## Not covered by the required zizmor check, with findings"
gh repo list "$org" --limit 500 --no-archived --json name,defaultBranchRef,isFork \
  --jq '.[] | select(.defaultBranchRef != null) | [.name, .defaultBranchRef.name, .isFork] | @tsv' | sort > "$config.repos"
trap 'rm -f "$config" "$config.repos"' EXIT

while IFS=$'\t' read -r repo branch fork; do
  covered="$(gh api "repos/$org/$repo/rules/branches/$branch" --jq '[.[] | select(.type == "workflows")] | length')"
  [ "$covered" = 0 ] || continue
  findings="$(uvx "zizmor@$version" --config "$config" --format json "$org/$repo" 2>/dev/null \
    | jq -r 'if length == 0 then empty else [.[].ident] | group_by(.) | map("\(.[0]) ×\(length)") | join(", ") end' || true)"
  [ -z "$findings" ] || echo "- \`$repo\`$([ "$fork" = true ] && echo ' (fork)'): $findings"
done < "$config.repos"

echo
echo "## Dependencies but no dependabot.yml"
while IFS=$'\t' read -r repo branch fork; do
  [ "$fork" = true ] && continue
  paths="$(gh api "repos/$org/$repo/git/trees/$branch?recursive=1" --jq '.tree[] | select(.type == "blob") | .path')"
  grep -qE '^\.github/dependabot\.ya?ml$' <<< "$paths" && continue
  if grep -qE '(^|/)(package\.json|pyproject\.toml|requirements[^/]*\.txt|setup\.py|uv\.lock|Dockerfile[^/]*|[^/]+\.tf|go\.mod|Cargo\.toml|Gemfile)$|^\.github/workflows/' <<< "$paths"; then
    echo "- \`$repo\`"
  fi
done < "$config.repos"
