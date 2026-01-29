#!/bin/bash
set -e

# ==================================================
# 配置区
# ==================================================
BRANCH="main"                 # GitHub 默认分支
COMMIT_PREFIX="auto_commit"   # 文件名前缀
DEFAULT_LINES=300             # 默认行数
MIN_LINES=1                   # 最小行数
MAX_LINES=10000               # 最大行数

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
# 用户输入函数
# ==================================================
get_user_input() {
    while true; do
        read -p "请输入要生成的文件行数 (默认: $DEFAULT_LINES, 输入 'r' 表示随机): " input

        # 处理空输入（使用默认值）
        if [ -z "$input" ]; then
            LINES_PER_FILE=$DEFAULT_LINES
            echo "使用默认行数: $LINES_PER_FILE"
            break
        fi

        # 处理随机选项
        if [ "$input" = "r" ] || [ "$input" = "R" ]; then
            # 生成 MIN_LINES 到 MAX_LINES 之间的随机数
            LINES_PER_FILE=$(( RANDOM % (MAX_LINES - MIN_LINES + 1) + MIN_LINES ))
            echo "生成随机行数: $LINES_PER_FILE"
            break
        fi

        # 验证输入是否为正整数
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge "$MIN_LINES" ] && [ "$input" -le "$MAX_LINES" ]; then
            LINES_PER_FILE=$input
            echo "使用指定行数: $LINES_PER_FILE"
            break
        else
            echo "错误：请输入 $MIN_LINES 到 $MAX_LINES 之间的正整数，或输入 'r' 获取随机值。"
        fi
    done
}

# ==================================================
# 版本号递增函数
# ==================================================
increment_version() {
    local version_type="${1:-patch}"
    local current_tag="$2"

    if [ -z "$current_tag" ]; then
        echo "v0.0.1"
        return 0
    fi

    current_tag=$(echo "$current_tag" | sed 's/^v//')

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
# 获取最新tag
# ==================================================
get_latest_tag() {
    local latest_tag=$(git tag --sort=-version:refname | head -n 1)
    echo "$latest_tag"
}

# ==================================================
# 生成随机内容函数
# ==================================================
generate_random_content() {
    local lines=$1
    local filename=$2
    local version=$3

    # 清空或创建文件
    > "$filename"

    # 多种随机内容模板
    local templates=(
        "Log entry #%LINE%: System operation completed at %TIMESTAMP%"
        "Data point %LINE%: Generated content for version %VERSION%"
        "Record %LINE%: Automated commit sequence %TIMESTAMP%"
        "Line %LINE%: Random data batch processing %TIMESTAMP%"
    )

    # 生成随机内容
    for i in $(seq 1 "$lines"); do
        # 随机选择模板
        template_index=$(( RANDOM % ${#templates[@]} ))
        template="${templates[$template_index]}"

        # 替换模板变量
        line_content=$(echo "$template" | \
            sed "s/%LINE%/$i/g" | \
            sed "s/%TIMESTAMP%/$(date -u "+%Y-%m-%d %H:%M:%S UTC")/g" | \
            sed "s/%VERSION%/$version/g")

        echo "$line_content" >> "$filename"
    done

    # 添加随机行尾内容（增加多样性）
    if [ $(( RANDOM % 2 )) -eq 0 ]; then
        echo "=== End of auto-generated content ===" >> "$filename"
    else
        echo "--- File complete. Total lines: $lines ---" >> "$filename"
    fi
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

# 获取用户输入的行数
get_user_input

# ==================================================
# 版本类型选择
# ==================================================
echo ""
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
# 获取当前最新tag并计算新版本
# ==================================================
LATEST_TAG=$(get_latest_tag)
echo "🔖 当前最新tag: ${LATEST_TAG:-无}"

NEW_TAG=$(increment_version "$VERSION_TYPE" "$LATEST_TAG")
echo "🚀 新版本号: $NEW_TAG"

# ==================================================
# 新建文件（使用随机内容生成）
# ==================================================
NOW=$(date -u "+%Y%m%d_%H%M%S")
FILE_NAME="${COMMIT_PREFIX}_${NOW}_${LINES_PER_FILE}lines.txt"

echo "📄 生成文件: $FILE_NAME"
echo "📊 文件行数: $LINES_PER_FILE"

# 生成随机内容
generate_random_content "$LINES_PER_FILE" "$FILE_NAME" "$NEW_TAG"

# ==================================================
# 提交文件
# ==================================================
git add "$FILE_NAME"

if git diff --cached --quiet; then
  echo "ℹ️ 没有变更，跳过提交"
  exit 0
fi

COMMIT_MSG="chore: auto commit ($NOW) - added $FILE_NAME ($LINES_PER_FILE lines) - version: $NEW_TAG"

GIT_COMMITTER_DATE="$NOW" \
GIT_AUTHOR_DATE="$NOW" \
git commit -m "$COMMIT_MSG"

# ==================================================
# 创建并推送tag
# ==================================================
echo "🏷️ 创建tag: $NEW_TAG"
git tag -a "$NEW_TAG" -m "Release: $NEW_TAG
- 自动生成于: $NOW
- 变更类型: $VERSION_TYPE
- 包含文件: $FILE_NAME
- 文件行数: $LINES_PER_FILE"

# ==================================================
# 更新变更日志
# ==================================================
if [ ! -f "CHANGELOG.md" ]; then
    echo "# 变更日志" > CHANGELOG.md
    echo "" >> CHANGELOG.md
    echo "> 自动生成的变更记录" >> CHANGELOG.md
fi

{
    echo ""
    echo "## $NEW_TAG ($(date -u "+%Y-%m-%d %H:%M:%S UTC"))"
    echo "- **自动提交**: $COMMIT_MSG"
    echo "- 生成文件: ${FILE_NAME}"
    echo "- 文件行数: ${LINES_PER_FILE}"
    echo "- 变更类型: ${VERSION_TYPE}"
} >> CHANGELOG.md

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
echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') | $NEW_TAG | $VERSION_TYPE | $FILE_NAME | $LINES_PER_FILE lines" >> "version_history.log"

echo ""
echo "✅ 自动提交完成!"
echo "📊 详情:"
echo "   - 文件: $FILE_NAME"
echo "   - 行数: $LINES_PER_FILE"
echo "   - 版本: $NEW_TAG"
echo "   - 分支: $BRANCH"
echo "   - 变更: $VERSION_TYPE"
echo "   - 时间: $NOW"