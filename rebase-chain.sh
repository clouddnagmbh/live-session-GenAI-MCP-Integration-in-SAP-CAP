#!/usr/bin/env bash
#
# Re-stack every demo branch after `main` changes.
#
# INVARIANT: each branch holds exactly ONE commit, so a branch's own first
# parent is the correct rebase base. Amend rather than adding commits.
#
# Do NOT use `git merge-base` here: once the parent branch has been rewritten,
# the merge base moves back and the rebase replays the parent's commit twice.
#
set -u

# Fail fast if the one-commit-per-branch invariant is broken.
check_invariant() {
  local prev=main bad=0
  for b in "${BRANCHES[@]}"; do
    local n; n=$(git rev-list --count "$prev..$b")
    if [ "$n" -ne 1 ]; then
      printf '  %-30s has %s commits over %s (expected 1)\n' "$b" "$n" "$prev"; bad=1
    fi
    prev=$b
  done
  [ "$bad" -eq 0 ] || { echo "invariant broken -- squash with: git reset --soft <branch>~N && git commit"; exit 1; }
}
BRANCHES=(
  01-recommendations-mock 02-recommendations-control 03-aicore-service
  04-genai-orchestration  05-vector-rag             06-mcp-basics
  07-mcp-query            08-mcp-actions            09-mcp-security
  10-agent-clients        11-genai-mcp-together
)

# Record each branch's original parent BEFORE anything is rewritten.
declare -a BASES
for i in "${!BRANCHES[@]}"; do
  BASES[$i]=$(git rev-parse "${BRANCHES[$i]}^")
done

check_invariant

prev=main
for i in "${!BRANCHES[@]}"; do
  b=${BRANCHES[$i]}
  if git rebase -q --onto "$prev" "${BASES[$i]}" "$b" >/dev/null 2>&1; then
    printf '  %-30s ok\n' "$b"
  else
    printf '  %-30s CONFLICT — fix, then `git rebase --continue` and re-run\n' "$b"
    exit 1
  fi
  prev=$b
done
git checkout -q main
echo "chain re-stacked onto main"
