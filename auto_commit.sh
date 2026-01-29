#!/bin/bash
set -e

# ==================================================
# 配置区
# ==================================================
BRANCH="main"                 # GitHub 默认分支
COMMIT_PREFIX="auto_commit"   # 文件名前缀
DEFAULT_LINES=300             # 默认行数
MIN_LINES=100                 # 最小行数
MAX_LINES=1000                # 最大行数
VERSION_FILE="version_history.log" # 版本记录文件

# ==================================================
# 自动版本类型决策函数
# ==================================================
auto_decide_version_type() {
    local latest_tag="$1"

    # 如果没有历史tag，从v0.0.1开始
    if [ -z "$latest_tag" ]; then
        echo "minor"  # 首个版本使用minor
        return 0
    fi

    # 提取最近的提交信息进行分析
    local recent_commits=$(git log --oneline -10 2>/dev/null | wc -l)

    # 获取最近5次提交中的功能添加关键词
    local feature_count=$(git log --oneline -5 --grep="feat:" 2>/dev/null | wc -l)
    local fix_count=$(git log --oneline -5 --grep="fix:" 2>/dev/null | wc -l)

    # 基于简单规则的决策逻辑
    if [ "$feature_count" -gt 2 ]; then
        echo "minor"   # 近期有多个功能提交，使用次版本升级
    elif [ "$fix_count" -gt 3 ]; then
        echo "patch"   # 主要是修复，使用修订版本升级
    else
        # 基于时间的自动决策：如果是月初，可能进行较大更新
        local current_day=$(date +%d)
        local current_month=$(date +%m)

        if [ "$current_day" -eq 1 ] && [ "$current_month" -eq 1 ]; then
            echo "major"   # 元旦进行主版本升级
        elif [ "$current_day" -le 7 ]; then
            echo "minor"   # 月初进行次版本升级
        else
            echo "patch"   # 默认使用修订版本升级
        fi
    fi
}

# ==================================================
# 随机行数生成函数
# ==================================================
generate_random_lines() {
    # 生成 MIN_LINES 到 MAX_LINES 之间的随机数
    echo $(( RANDOM % (MAX_LINES - MIN_LINES + 1) + MIN_LINES ))
}

# ==================================================
# 随机内容生成函数
# ==================================================
generate_random_content() {
    local lines=$1
    local filename=$2
    local version=$3

    # 清空或创建文件
    > "$filename"

    # 多种随机内容模板
    local templates=(
        "Auto-generated log entry #%LINE%: System operation completed at %TIMESTAMP%"
        "Data point %LINE%: Automated content for version %VERSION%"
        "Commit record %LINE%: Batch processing sequence %TIMESTAMP%"
        "Log sequence %LINE%: Automated git commit %TIMESTAMP%"
        "Test data %LINE%: Continuous integration build %VERSION%"
    )

    # 随机句子库
    local sentences=(
        "This is an automated commit for version control testing."
        "The system generated this content as part of routine maintenance."
        "This entry was created by an automated script for CI/CD purposes."
        "Random data batch used for testing version control automation."
        "Automated content generation for git workflow validation."
    )

    # 生成随机内容
    for i in $(seq 1 "$lines"); do
        # 每10行插入一个随机句子增加多样性
        if [ $(( i % 10 )) -eq 0 ] && [ $i -ne 0 ]; then
            local sentence_index=$(( RANDOM % ${#sentences[@]} ))
            echo "${sentences[$sentence_index]}" >> "$filename"
            continue
        fi

        # 随机选择模板
        local template_index=$(( RANDOM % ${#templates[@]} ))
        local template="${templates[$template_index]}"

        # 替换模板变量
        local line_content=$(echo "$template" | \
            sed "s/%LINE%/$i/g" | \
            sed "s/%TIMESTAMP%/$(date -u "+%Y-%m-%d %H:%M:%S UTC")/g" | \
            sed "s/%VERSION%/$version/g")

        echo "$line_content" >> "$filename"
    done

    # 添加文件尾注
    echo "=== Auto-generated file ===" >> "$filename"
    echo "File: $filename" >> "$filename"
    echo "Version: $version" >> "$filename"
    echo "Lines: $lines" >> "$filename"
    echo "Generated: $(date -u "+%Y-%m-%d %H:%M:%S UTC")" >> "$filename"
    echo "============================" >> "$filename"
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
    git fetch --tags origin 2>/dev/null || true
    local latest_tag=$(git tag --sort=-version:refname | head -n 1)
    echo "$latest_tag"
}

# ==================================================
# 主程序
# ==================================================
echo "🚀 开始完全自动化Git提交流程..."

# 找Git根目录
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
    echo "❌ 错误：未在目录结构中发现Git仓库"
    exit 1
fi
cd "$REPO_DIR"
echo "📦 Git仓库根目录: $REPO_DIR"

# 切换到指定分支
git fetch origin 2>/dev/null || true
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH" 2>/dev/null
    git reset --hard "origin/$BRANCH" 2>/dev/null || true
else
    git checkout -b "$BRANCH" "origin/$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
fi

# 获取当前最新tag并自动决定版本类型
LATEST_TAG=$(get_latest_tag)
echo "🔖 当前最新tag: ${LATEST_TAG:-无}"

VERSION_TYPE=$(auto_decide_version_type "$LATEST_TAG")
NEW_TAG=$(increment_version "$VERSION_TYPE" "$LATEST_TAG")
echo "🎯 自动决策版本类型: $VERSION_TYPE"
echo "🚀 新版本号: $NEW_TAG"

# 生成随机行数
LINES_PER_FILE=$(generate_random_lines)
echo "📊 生成随机行数: $LINES_PER_FILE"

# 创建新文件
NOW=$(date -u "+%Y%m%d_%H%M%S")
FILE_NAME="${COMMIT_PREFIX}_${NOW}_${LINES_PER_FILE}lines.txt"

echo "📄 生成文件: $FILE_NAME"

# 生成随机内容
generate_random_content "$LINES_PER_FILE" "$FILE_NAME" "$NEW_TAG"

# 提交文件
git add "$FILE_NAME"

if git diff --cached --quiet; then
    echo "ℹ️ 没有检测到变更，跳过提交"
    exit 0
fi

COMMIT_MSG="chore: auto commit ($NOW) - $FILE_NAME ($LINES_PER_FILE lines) - $NEW_TAG"

GIT_COMMITTER_DATE="$NOW" \
GIT_AUTHOR_DATE="$NOW" \
git commit -m "$COMMIT_MSG" --quiet

# 创建并推送tag
echo "🏷️ 创建tag: $NEW_TAG"
git tag -a "$NEW_TAG" -m "Auto-generated release: $NEW_TAG
- 生成时间: $NOW
- 变更类型: $VERSION_TYPE
- 文件: $FILE_NAME
- 行数: $LINES_PER_FILE" --quiet

# 更新变更日志
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
    echo "- 提交哈希: $(git rev-parse --short HEAD)"
} >> CHANGELOG.md

git add CHANGELOG.md
git commit --amend --no-edit --quiet

# 推送到远程
echo "📤 推送到远程仓库..."
if git push origin "$BRANCH" --quiet && git push origin "$NEW_TAG" --quiet; then
    echo "✅ 推送成功"
else
    echo "⚠️ 推送失败，可能是网络问题或权限不足"
fi

# 记录版本信息
echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') | $NEW_TAG | $VERSION_TYPE | $FILE_NAME | $LINES_PER_FILE lines | $(git rev-parse --short HEAD)" >> "$VERSION_FILE"

echo ""
echo "✅ 完全自动化提交完成!"
echo "📊 执行详情:"
echo "   - 文件: $FILE_NAME"
echo "   - 行数: $LINES_PER_FILE"
echo "   - 版本: $NEW_TAG"
echo "   - 分支: $BRANCH"
echo "   - 变更类型: $VERSION_TYPE"
echo "   - 提交时间: $NOW"
echo "   - 提交哈希: $(git rev-parse --short HEAD)"