# .github

Organization-wide defaults for Mozilla-Data-Collective repositories.

- `.github/workflows/zizmor.yml` is the zizmor check that an organization ruleset requires on pull requests in every covered repository.
- `scripts/audit.sh` lists repos the zizmor check doesn't cover that have findings, and repos with dependencies but no `dependabot.yml`. Run it monthly with a `gh` login that can read every repo; it needs `jq` and `uvx`.
