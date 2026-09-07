#!/usr/bin/env bash
#
# Re-stack every demo branch after `main` changes.
#
# The chain is linear and each branch holds exactly ONE commit, so a branch's
# own first parent is the correct rebase base. Do NOT use `git merge-base` here:
# once the parent branch has been rewritten, the merge base moves back and the
# rebase replays the parent's commit a second time.
#
set -u
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
