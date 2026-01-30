#!/bin/bash

# GitHub仓库维护脚本（自动推送版）
# 注意：请在Git仓库目录下运行，提交后将自动推送到远程仓库

set -e  # 如果任何命令失败则退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 打印彩色信息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否在git仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "当前目录不是Git仓库，请在Git仓库目录中运行此脚本"
    exit 1
fi

# 获取当前分支
CURRENT_BRANCH=$(git branch --show-current)
info "当前分支: $CURRENT_BRANCH"

# 检查是否在main分支，如果不是则尝试切换
if [[ "$CURRENT_BRANCH" != "main" ]] && [[ "$CURRENT_BRANCH" != "master" ]]; then
    info "尝试切换到main/master分支..."
    if git show-ref --verify --quiet refs/heads/main; then
        git checkout main
        CURRENT_BRANCH="main"
    elif git show-ref --verify --quiet refs/heads/master; then
        git checkout master
        CURRENT_BRANCH="master"
    else
        error "找不到main或master分支，将使用当前分支: $CURRENT_BRANCH"
    fi
fi

# 允许自定义提交信息
COMMIT_MESSAGE="${1:-}"
if [[ -z "$COMMIT_MESSAGE" ]]; then
    # 随机生成有意义的提交信息
    COMMIT_TYPES=("docs" "chore" "refactor" "style" "test" "ci" "build")
    COMMIT_SCOPES=("README" "deps" "config" "scripts" "docs" "utils" "logs")
    ACTIONS=("update" "improve" "fix" "cleanup" "add" "optimize" "bump")
    DESCRIPTIONS=("files" "code" "config" "dependencies" "documentation" "scripts" "structure")

    TYPE=${COMMIT_TYPES[$RANDOM % ${#COMMIT_TYPES[@]}]}
    SCOPE=${COMMIT_SCOPES[$RANDOM % ${#COMMIT_SCOPES[@]}]}
    ACTION=${ACTIONS[$RANDOM % ${#ACTIONS[@]}]}
    DESC=${DESCRIPTIONS[$RANDOM % ${#DESCRIPTIONS[@]}]}

    COMMIT_MESSAGE="$TYPE($SCOPE): $ACTION $DESC"
fi

info "提交信息: $COMMIT_MESSAGE"

# 有用的维护任务
info "执行维护任务..."

# 1. 创建/更新维护日志文件
LOG_DIR=".maintenance_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/maintenance_$(date +%Y%m).log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP - 执行维护任务: $COMMIT_MESSAGE" >> "$LOG_FILE"

# 2. 创建或更新.gitignore（如果需要）
if [[ ! -f ".gitignore" ]]; then
    info "创建.gitignore文件..."
    cat > .gitignore << 'EOF'
# 日志文件
*.log
logs/

# 临时文件
*.tmp
*.temp
tmp/
temp/

# 编辑器文件
.vscode/
.idea/
*.swp
*.swo

# 系统文件
.DS_Store
Thumbs.db

# 维护日志
.maintenance_logs/
EOF
fi

# 3. 创建或更新CHANGELOG.md
if [[ ! -f "CHANGELOG.md" ]]; then
    info "创建CHANGELOG.md文件..."
    cat > CHANGELOG.md << EOF
# 更新日志

## [未发布]

### 新增
- 初始化项目

---

*自动生成于 $TIMESTAMP*
EOF
elif [[ -f "CHANGELOG.md" ]] && grep -q "## \[未发布\]" "CHANGELOG.md"; then
    info "更新CHANGELOG.md..."
    # 在"## [未发布]"部分下添加新条目
    if ! grep -q "$(date +%Y-%m-%d)" "CHANGELOG.md"; then
        sed -i "/## \[未发布\]/a\\\n### $(date +%Y-%m-%d)\\n- 自动维护更新" CHANGELOG.md
    fi
fi

# 4. 创建有用的配置文件示例（如果不存在）
if [[ ! -f ".editorconfig" ]]; then
    cat > .editorconfig << 'EOF'
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false
EOF
    info "创建.editorconfig文件"
fi

# 检查是否有任何更改
if [[ -z $(git status --porcelain) ]]; then
    info "没有检测到更改，添加维护日志..."
    git add "$LOG_FILE"
else
    # 添加所有更改
    git add .
fi

# 检查是否真的有内容要提交
if [[ -z $(git diff --cached --name-only) ]]; then
    warning "没有要提交的更改，跳过提交"
    exit 0
fi

# 提交更改
info "提交更改..."
git commit -m "$COMMIT_MESSAGE"

# 自动推送到远程仓库
info "自动推送到远程仓库..."
if git push origin "$CURRENT_BRANCH" 2>&1; then
    success "✅ 完成！更改已提交并推送到远程仓库"
else
    error "推送失败，请检查网络连接和权限"
    error "你可以稍后使用 'git push origin $CURRENT_BRANCH' 手动推送"
fi