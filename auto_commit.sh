#!/bin/bash
set -e

echo "🚀 启动全自动GitHub活跃度维护脚本..."

# ==================================================
# 配置区 - 可根据需要调整
# ==================================================
BRANCH="main"                 # 操作分支
COMMIT_PREFIX="chore"         # 提交信息前缀
DEFAULT_LINES=50              # 默认生成文件行数
MIN_LINES=10                  # 最小行数
MAX_LINES=100                # 最大行数
MAX_DAILY_COMMITS=5          # 每日最大提交次数（避免过量）
SKIP_WEEKENDS="true"          # 是否跳过周末（true/false）

# ==================================================
# 随机提交决策函数
# ==================================================
should_commit_today() {
    if [ "$SKIP_WEEKENDS" = "true" ]; then
        local day_of_week=$(date +%u)  # 1-7 (周一为1)
        if [ "$day_of_week" -ge 6 ]; then
            echo "false"
            return 0
        fi
    fi
    # 工作日有70%概率执行提交
    local chance=$(( RANDOM % 100 ))
    if [ "$chance" -lt 70 ]; then
        echo "true"
    else
        echo "false"
    fi
}

# ==================================================
# 生成随机内容
# ==================================================
generate_random_content() {
    local filename=$1
    local lines=$2

    # 创建或清空文件
    > "$filename"

    # 生成随机内容
    for i in $(seq 1 "$lines"); do
        echo "Auto-generated line $i: $(date -u '+%Y-%m-%d %H:%M:%S UTC') - Commit $(git rev-parse --short HEAD)" >> "$filename"
    done

    # 添加文件信息尾注
    echo "==================================" >> "$filename"
    echo "File: $filename" >> "$filename"
    echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$filename"
    echo "Lines: $lines" >> "$filename"
    echo "Branch: $BRANCH" >> "$filename"
}

# ==================================================
# 主执行逻辑
# ==================================================
main() {
    echo "📅 检查今日是否执行提交..."
    local commit_today=$(should_commit_today)

    if [ "$commit_today" = "false" ]; then
        echo "ℹ️ 今日跳过提交（周末或随机跳过）"
        exit 0
    fi

    # 配置Git用户信息（使用Actions的默认信息）
    git config --local user.name "github-actions[bot]"
    git config --local user.email "github-actions[bot]@users.noreply.github.com"

    # 切换到操作分支
    git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

    # 生成随机提交次数 (1到MAX_DAILY_COMMITS之间)
    local commit_count=$(( (RANDOM % MAX_DAILY_COMMITS) + 1 ))

    echo "🎯 今日计划提交次数: $commit_count"

    for i in $(seq 1 "$commit_count"); do
        echo "--- 开始第 $i 次提交 ---"

        # 生成随机行数
        local lines=$(( RANDOM % (MAX_LINES - MIN_LINES + 1) + MIN_LINES ))

        # 生成唯一文件名
        local timestamp=$(date -u '+%Y%m%d_%H%M%S')
        local filename="auto_${timestamp}_${lines}lines.txt"

        # 生成文件内容
        generate_random_content "$filename" "$lines"

        # 添加到暂存区并提交
        git add "$filename"

        # 检查是否有变更需要提交
        if git diff --staged --quiet; then
            echo "ℹ️ 没有检测到变更，跳过本次提交"
            rm "$filename"
            continue
        fi

        # 生成提交信息
        local commit_msg="${COMMIT_PREFIX}: auto-generated commit #${i} (${lines} lines)"

        # 执行提交
        if git commit -m "$commit_msg" --quiet; then
            echo "✅ 第 $i 次提交成功"
        else
            echo "❌ 第 $i 次提交失败"
        fi

        # 短暂延迟，模拟人类操作间隔
        sleep $(( (RANDOM % 10) + 1 ))
    done

    # 推送到远程仓库
    echo "📤 推送更改到远程仓库..."
    if git push origin "$BRANCH" --quiet; then
        echo "✅ 推送成功"
        echo "📊 今日完成提交: $commit_count 次"
    else
        echo "❌ 推送失败"
    fi
}

# 执行主函数
main