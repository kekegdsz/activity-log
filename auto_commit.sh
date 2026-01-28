#!/bin/bash
set -e

# ==================================================
# 配置区（按需改）
# ==================================================
BRANCH="main"                 # GitHub 默认分支，保证贡献统计深绿
COMMIT_FILE=".auto_commit_log"
MAX_LINES=1000                # 防止文件无限长

# ==================================================
# 找 Git 根目录
# ==================================================
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

# ==================================================
# 切到分支（解决 Jenkins detached HEAD）
# ==================================================
git fetch origin
git checkout "$BRANCH" || git switch -c "$BRANCH" origin/"$BRANCH"
git reset --hard origin/"$BRANCH"

# ==================================================
# 制造变更（保证 GitHub 统计贡献）
# ==================================================
# 使用 UTC 时间，确保 GitHub 统计正确
NOW=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
echo "auto commit at $NOW" >> "$COMMIT_FILE"

# 控制文件大小
LINES=$(wc -l < "$COMMIT_FILE")
if [ "$LINES" -gt "$MAX_LINES" ]; then
  tail -n 200 "$COMMIT_FILE" > "$COMMIT_FILE.tmp"
  mv "$COMMIT_FILE.tmp" "$COMMIT_FILE"
fi

# ==================================================
# 提交
# ==================================================
git add "$COMMIT_FILE"

if git diff --cached --quiet; then
  echo "ℹ️ No changes, skip commit"
  exit 0
fi

# 设置 commit 时间为 UTC，保证 GitHub 活跃度统计
GIT_COMMITTER_DATE="$NOW" \
GIT_AUTHOR_DATE="$NOW" \
git commit -m "chore: auto commit ($NOW)"

git push origin "$BRANCH"

echo "✅ Auto commit done"
