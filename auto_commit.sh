#!/bin/bash

# GitHub仓库维护脚本
# 注意：请确保在Git仓库目录下运行此脚本
# 功能：执行有用的仓库维护任务，避免空提交

set -e  # 如果有命令失败则退出

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

# 检查是否在main分支
if [[ "$CURRENT_BRANCH" != "main" ]] && [[ "$CURRENT_BRANCH" != "master" ]]; then
    warning "当前不在main/master分支，是否要切换到main分支? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # 尝试切换到main分支
        if git show-ref --verify --quiet refs/heads/main; then
            git checkout main
            CURRENT_BRANCH="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            git checkout master
            CURRENT_BRANCH="master"
        else
            error "找不到main或master分支"
            exit 1
        fi
    else
        info "继续在当前分支 $CURRENT_BRANCH 上操作"
    fi
fi

# 允许自定义提交信息
COMMIT_MESSAGE="${1:-}"
if [[ -z "$COMMIT_MESSAGE" ]]; then
    # 生成有意义的提交信息
    COMMIT_TYPES=("docs" "chore" "refactor" "style" "test")
    COMMIT_SCOPES=("README" "deps" "config" "scripts" "docs")
    ACTIONS=("update" "improve" "fix" "cleanup" "add")

    TYPE=${COMMIT_TYPES[$RANDOM % ${#COMMIT_TYPES[@]}]}
    SCOPE=${COMMIT_SCOPES[$RANDOM % ${#COMMIT_SCOPES[@]}]}
    ACTION=${ACTIONS[$RANDOM % ${#ACTIONS[@]}]}

    COMMIT_MESSAGE="$TYPE($SCOPE): $ACTION files"
fi

info "提交信息: $COMMIT_MESSAGE"

# 有用的维护任务
echo -e "\n${BLUE}执行维护任务...${NC}"

# 1. 更新README.md（如果有的话）
if [[ -f "README.md" ]]; then
    info "更新README.md..."
    # 在README末尾添加更新时间戳（在特定标记之后）
    if grep -q "<!-- AUTO-UPDATE -->" README.md; then
        # 如果存在标记，则在标记后插入
        sed -i "/<!-- AUTO-UPDATE -->/a\\
**最后维护时间**: $(date '+%Y-%m-%d %H:%M:%S')" README.md
    else
        # 否则添加到文件末尾
        echo -e "\n---\n*最后自动维护: $(date '+%Y-%m-%d %H:%M:%S')*" >> README.md
    fi
fi

# 2. 创建/更新维护日志文件
LOG_DIR=".maintenance_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/maintenance_$(date +%Y%m).log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 执行维护任务: $COMMIT_MESSAGE" >> "$LOG_FILE"

# 3. 创建或更新.gitignore（如果需要）
if [[ ! -f ".gitignore" ]]; then
    info "创建.gitignore文件..."
    cat > .gitignore << EOF
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
EOF
elif [[ -f ".gitignore" ]] && ! grep -q "维护日志" .gitignore; then
    # 确保维护日志不被跟踪
    echo -e "\n# 维护日志" >> .gitignore
    echo ".maintenance_logs/" >> .gitignore
fi

# 4. 运行项目特定的检查（可选）
# 这里可以根据项目类型添加特定的检查
# 例如：如果是Node.js项目，运行 npm audit
# 如果是Python项目，运行 black 格式化等

# 检查是否有任何更改
if [[ -z $(git status --porcelain) ]]; then
    info "没有检测到更改，正在创建一个小更改..."
    # 如果没有更改，在日志文件中添加一行
    echo "无代码更改，仅更新日志" >> "$LOG_FILE"
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

# 询问是否推送
echo -e "\n${YELLOW}是否要推送到远程仓库? (y/N)${NC}"
read -r PUSH_RESPONSE
if [[ "$PUSH_RESPONSE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info "推送到远程仓库..."
    git push origin "$CURRENT_BRANCH"
    success "✅ 完成！更改已提交并推送到远程仓库"
else
    success "✅ 完成！更改已提交到本地仓库，但未推送"
    info "你可以稍后使用 'git push' 手动推送"
fi