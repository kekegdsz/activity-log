#!/bin/bash
set -e

# ==================================================
# 配置区（按需改）
# ==================================================
BRANCH="main"                 # main / master / dev
COMMIT_FILE=".auto_commit_log"
MAX_LINES=1000                # 防止文件无限长

# ==================================================
# 向上查找 Git 根目录（最稳）
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

# ==================================================
# 定位脚本目录并查找 git root
# ==================================================
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR" || exit 1

REPO_DIR=$(find_git_root)

if [ -z "$REPO_DIR" ]; then
  echo "❌ Not a git repository (cannot find .git)"
  exit 1
fi

cd "$REPO_DIR"
echo "📦 Git root: $REPO_DIR"

# ==================================================
# Git 基础校验
# ==================================================
git rev-parse --is-inside-work-tree >/dev/null

# ==================================================
# 同步远端
# ==================================================
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

# ==================================================
# 制造变更
# ==================================================
NOW=$(date "+%Y-%m-%d %H:%M:%S")
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

git commit -m "chore: auto commit ($(date +%Y%m%d))"
git push origin "$BRANCH"

echo "✅ Auto commit done"