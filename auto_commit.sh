#!/bin/bash

# GitHub仓库维护脚本（Jenkins优化版）
# 修复detached HEAD状态和.gitignore问题

set -e  # 如果任何命令失败则退出

# 颜色定义（Jenkins兼容）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 打印彩色信息（Jenkins兼容）
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否在git仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "当前目录不是Git仓库"
    exit 1
fi

# Jenkins特殊处理：检测detached HEAD状态[6](@ref)
CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
    info "检测到detached HEAD状态，尝试寻找远程分支..."
    # 获取当前检出的commit对应的远程分支
    REMOTE_BRANCH=$(git log -n 1 --pretty=%D HEAD | grep -o 'origin/[^,]*' | head -1 | sed 's#origin/##')

    if [[ -n "$REMOTE_BRANCH" ]]; then
        info "切换到分支: $REMOTE_BRANCH"
        git checkout -b "jenkins-$REMOTE_BRANCH" "origin/$REMOTE_BRANCH" 2>/dev/null || git checkout "$REMOTE_BRANCH"
        CURRENT_BRANCH=$(git branch --show-current)
    else
        # 如果找不到远程分支，使用main或master
        if git show-ref --verify --quiet refs/heads/main; then
            git checkout main
            CURRENT_BRANCH="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            git checkout master
            CURRENT_BRANCH="master"
        else
            error "无法确定分支，创建临时分支"
            git checkout -b jenkins-temp
            CURRENT_BRANCH="jenkins-temp"
        fi
    fi
fi

info "当前分支: $CURRENT_BRANCH"

# 设置Git用户信息（Jenkins中必须设置）[6,8](@ref)
git config --global user.name "Jenkins"
git config --global user.email "jenkins@$(hostname)"

# 生成提交信息
COMMIT_MESSAGE="${1:-}"
if [[ -z "$COMMIT_MESSAGE" ]]; then
    COMMIT_TYPES=("docs" "chore" "refactor" "style" "ci")
    COMMIT_SCOPES=("README" "deps" "config" "scripts" "docs" "jenkins")
    ACTIONS=("update" "improve" "fix" "cleanup" "optimize")

    TYPE=${COMMIT_TYPES[$RANDOM % ${#COMMIT_TYPES[@]}]}
    SCOPE=${COMMIT_SCOPES[$RANDOM % ${#COMMIT_SCOPES[@]}]}
    ACTION=${ACTIONS[$RANDOM % ${#ACTIONS[@]}]}

    COMMIT_MESSAGE="$TYPE($SCOPE): $ACTION by Jenkins"
fi

info "提交信息: $COMMIT_MESSAGE"

# 维护任务 - 使用不会被.gitignore排除的目录
info "执行维护任务..."

# 1. 使用jenkins_logs而不是.maintenance_logs
LOG_DIR="jenkins_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/maintenance_$(date +%Y%m%d).log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 记录构建信息
echo "=== Jenkins维护日志 ===" >> "$LOG_FILE"
echo "时间: $TIMESTAMP" >> "$LOG_FILE"
echo "分支: $CURRENT_BRANCH" >> "$LOG_FILE"
echo "提交信息: $COMMIT_MESSAGE" >> "$LOG_FILE"
echo "工作目录: $(pwd)" >> "$LOG_FILE"
echo "=== 结束 ===" >> "$LOG_FILE"

# 2. 更新README.md（如果存在）
if [[ -f "README.md" ]]; then
    info "更新README.md..."
    # 在文件末尾添加Jenkins构建标记
    if ! grep -q "<!-- Jenkins Build -->" "README.md"; then
        echo -e "\n<!-- Jenkins Build: 最后更新于 $TIMESTAMP -->" >> "README.md"
    fi
fi

# 3. 创建有用的配置文件
if [[ ! -f "jenkins-build.info" ]]; then
    cat > "jenkins-build.info" << EOF
# Jenkins构建信息
构建时间: $TIMESTAMP
构建分支: $CURRENT_BRANCH
自动生成: true
EOF
fi

# 添加文件到Git（强制添加被忽略的文件）[3](@ref)
info "添加文件到Git..."
git add -f "$LOG_DIR/" 2>/dev/null || true
git add "jenkins-build.info" 2>/dev/null || true
git add "README.md" 2>/dev/null || true

# 检查是否有更改需要提交
if [[ -z $(git status --porcelain) ]]; then
    info "没有检测到更改，创建小更改..."
    # 确保日志文件被添加
    echo "构建时间: $TIMESTAMP" >> "$LOG_FILE"
    git add -f "$LOG_FILE"
fi

# 最终检查
if [[ -z $(git diff --cached --name-only) ]]; then
    warning "没有要提交的更改"
    # 创建一个小更改避免空提交
    echo "timestamp: $(date +%s)" >> "jenkins-timestamp.txt"
    git add -f "jenkins-timestamp.txt"
fi

# 提交更改[6](@ref)
info "提交更改..."
if git commit -m "$COMMIT_MESSAGE" 2>/dev/null; then
    success "提交成功"
else
    error "提交失败，可能没有更改"
    exit 1
fi

# 推送到远程仓库[6](@ref)
info "推送到远程仓库..."
if git push origin "$CURRENT_BRANCH"; then
    success "✅ Jenkins构建完成！更改已提交并推送"
else
    error "推送失败，请检查权限和网络连接"
    # 尝试创建PR或使用其他方式推送
    if [[ "$CURRENT_BRANCH" == jenkins-* ]]; then
        info "尝试推送临时分支"
        git push -u origin "$CURRENT_BRANCH"
    fi
fi
