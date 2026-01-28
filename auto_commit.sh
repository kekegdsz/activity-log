#!/bin/bash
set -e

# ==================================================
# 配置区
# ==================================================
BRANCH="main"                 # GitHub 默认分支
COMMIT_PREFIX="auto_commit"   # 文件名前缀
LINES_PER_FILE=300            # 每个文件写多少行

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
# 切到分支
# ==================================================
git fetch origin
git checkout "$BRANCH" || git switch -c "$BRANCH" origin/"$BRANCH"
git reset --hard origin/"$BRANCH"

# ==================================================
# 新建文件
# ==================================================
NOW=$(date -u "+%Y%m%d_%H%M%S")
FILE_NAME="${COMMIT_PREFIX}_${NOW}.txt"

echo "生成文件: $FILE_NAME"

# 生成几百行示例内容
for i in $(seq 1 "$LINES_PER_FILE"); do
  echo "Line $i: auto commit at $NOW" >> "$FILE_NAME"
done

# ==================================================
# 提交文件
# ==================================================
git add "$FILE_NAME"

if git diff --cached --quiet; then
  echo "ℹ️ No changes, skip commit"
  exit 0
fi

GIT_COMMITTER_DATE="$NOW" \
GIT_AUTHOR_DATE="$NOW" \
git commit -m "chore: auto commit ($NOW) - added $FILE_NAME"

git push origin "$BRANCH"

echo "✅ Auto commit done: $FILE_NAME"
