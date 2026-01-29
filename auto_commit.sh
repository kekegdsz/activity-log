#!/bin/bash
set -e

# ==================================================
# 配置区
# ==================================================
BRANCH="main"                 # GitHub 默认分支
COMMIT_PREFIX="auto_commit"   # 文件名前缀
LINES_PER_FILE=300            # 每个文件写多少行
VERSION_FILE="version.log"    # 版本记录文件

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

# ==================================================
# 版本号递增函数 [1,5](@ref)
# ==================================================
increment_version() {
    local version_type="${1:-patch}"
    local current_tag="$2"

    # 如果没有当前tag，从v0.0.0开始
    if [ -z "$current_tag" ]; then
        echo "v0.0.1"
        return 0
    fi

    # 移除v前缀以便处理数字
    current_tag=$(echo "$current_tag" | sed 's/^v//')

    # 使用awk进行版本号递增 [1](@ref)
    case "$version_type" in
        "major")
            echo "$current_tag" | awk -F. '{
                $1 = $1 + 1;
                $2 = 0;
                $3 = 0;
                print "v" $1 "." $2 "." $3
            }'
            ;;
        "minor")
            echo "$current_tag" | awk -F. '{
                $2 = $2 + 1;
                $3 = 0;
                print "v" $1 "." $2 "." $3
            }'
            ;;
        "patch"|*)
            echo "$current_tag" | awk -F. '{
                $3 = $3 + 1;
                print "v" $1 "." $2 "." $3
            }'
            ;;
    esac
}

# ==================================================
# 获取最新tag [1](@ref)
# ==================================================
get_latest_tag() {
    # 获取所有tag并按版本号排序
    local latest_tag=$(git tag --sort=-version:refname | head -n 1)
    echo "$latest_tag"
}

# ==================================================
# 验证仓库状态 [1](@ref)
# ==================================================
check_repo_status() {
    if [ -n "$(git status --porcelain)" ]; then
        echo "❌ 错误：仓库中有未提交的更改，请先处理"
        exit 1
    fi
}

# ==================================================
# 生成变更日志 [5](@ref)
# ==================================================
generate_changelog_entry() {
    local version="$1"
    local commit_msg="$2"
    local timestamp=$(date -u "+%Y-%m-%d %H:%M:%S UTC")

    cat << EOF >> CHANGELOG.md

## $version ($timestamp)
- **自动提交**: $commit_msg
- 生成文件: ${FILE_NAME}
- 变更类型: ${VERSION_TYPE}

EOF
}

# ==================================================
# 主程序
# ==================================================
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

REPO_DIR=$(find_git_root)
if [ -z "$REPO_DIR" ]; then
  echo "❌ Not a git repository"
  exit 1
fi
cd "$REPO_DIR"
echo "📦 Git root: $REPO_DIR"

# 检查仓库状态
check_repo_status

# ==================================================
# 版本类型选择
# ==================================================
echo "请选择版本更新类型:"
echo "1) patch - 修订版本 (v1.0.0 → v1.0.1)"
echo "2) minor - 次版本 (v1.0.0 → v1.1.0)"
echo "3) major - 主版本 (v1.0.0 → v2.0.0)"
read -p "输入选择 (默认1): " version_choice

case "$version_choice" in
    1|"") VERSION_TYPE="patch" ;;
    2) VERSION_TYPE="minor" ;;
    3) VERSION_TYPE="major" ;;
    *) echo "❌ 无效选择，使用默认patch"; VERSION_TYPE="patch" ;;
esac

echo "🎯 选择的版本类型: $VERSION_TYPE"

# ==================================================
# 切到分支
# ==================================================
git fetch origin
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH"
    git reset --hard origin/"$BRANCH"
else
    git switch -c "$BRANCH" origin/"$BRANCH" || git switch -c "$BRANCH"
fi

# ==================================================
# 获取当前最新tag并计算新版本 [1](@ref)
# ==================================================
LATEST_TAG=$(get_latest_tag)
echo "🔖 当前最新tag: ${LATEST_TAG:-无}"

NEW_TAG=$(increment_version "$VERSION_TYPE" "$LATEST_TAG")
echo "🚀 新版本号: $NEW_TAG"

# ==================================================
# 新建文件
# ==================================================
NOW=$(date -u "+%Y%m%d_%H%M%S")
FILE_NAME="${COMMIT_PREFIX}_${NOW}.txt"

echo "📄 生成文件: $FILE_NAME"

# 生成几百行示例内容
for i in $(seq 1 "$LINES_PER_FILE"); do
  echo "Line $i: auto commit at $NOW - Version: $NEW_TAG" >> "$FILE_NAME"
done

# ==================================================
# 提交文件
# ==================================================
git add "$FILE_NAME"

if git diff --cached --quiet; then
  echo "ℹ️ 没有变更，跳过提交"
  exit 0
fi

COMMIT_MSG="chore: auto commit ($NOW) - added $FILE_NAME - version: $NEW_TAG"

GIT_COMMITTER_DATE="$NOW" \
GIT_AUTHOR_DATE="$NOW" \
git commit -m "$COMMIT_MSG"

# ==================================================
# 创建并推送tag [1,5](@ref)
# ==================================================
echo "🏷️ 创建tag: $NEW_TAG"
git tag -a "$NEW_TAG" -m "Release: $NEW_TAG
- 自动生成于: $NOW
- 变更类型: $VERSION_TYPE
- 包含文件: $FILE_NAME"

# ==================================================
# 更新变更日志 [5](@ref)
# ==================================================
if [ ! -f "CHANGELOG.md" ]; then
    echo "# 变更日志" > CHANGELOG.md
    echo "" >> CHANGELOG.md
    echo "> 自动生成的变更记录" >> CHANGELOG.md
fi

generate_changelog_entry "$NEW_TAG" "$COMMIT_MSG"
git add CHANGELOG.md
git commit --amend --no-edit

# ==================================================
# 推送到远程
# ==================================================
echo "📤 推送到远程仓库..."
git push origin "$BRANCH"
git push origin "$NEW_TAG"

# ==================================================
# 记录版本信息
# ==================================================
echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') | $NEW_TAG | $VERSION_TYPE | $FILE_NAME" >> "$VERSION_FILE"

echo "✅ 自动提交完成!"
echo "📊 详情:"
echo "   - 文件: $FILE_NAME"
echo "   - 版本: $NEW_TAG"
echo "   - 分支: $BRANCH"
echo "   - 变更: $VERSION_TYPE"
echo "   - 时间: $NOW"