#!/bin/bash
set -e

BRANCH="main"
COMMIT_FILE=".auto_commit_log"
MAX_LINES=1000

# 找 git 根目录
find_git_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.git" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

REPO_DIR=$(find_git_root)
if [ -z "$REPO_DIR" ]; then
  echo "❌ Not a git repository"
  exit 1
fi
cd "$REPO_DIR"
echo "📦 Git root: $REPO_DIR"

# =====================
# 切到分支（解决 Jenkins detached HEAD）
# =====================
git fetch origin
git checkout "$BRANCH" || git switch -c "$BRANCH" origin/"$BRANCH"
git reset --hard origin/"$BRANCH"

# =====================
# 制造变更
# =====================
NOW=$(date "+%Y-%m-%d %H:%M:%S")
echo "auto commit at $NOW" >> "$COMMIT_FILE"

LINES=$(wc -l < "$COMMIT_FILE")
if [ "$LINES" -gt "$MAX_LINES" ]; then
  tail -n 200 "$COMMIT_FILE" > "$COMMIT_FILE.tmp"
  mv "$COMMIT_FILE.tmp" "$COMMIT_FILE"
fi

# =====================
# 提交
# =====================
git add "$COMMIT_FILE"

if git diff --cached --quiet; then
  echo "ℹ️ No changes, skip commit"
  exit 0
fi

git commit -m "chore: auto commit ($(date +%Y%m%d))"
git push origin "$BRANCH"

echo "✅ Auto commit done"
