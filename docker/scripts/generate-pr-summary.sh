#!/bin/bash
# scripts/generate-pr-summary.sh

set -e

# 環境変数チェック
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY is not set"
    exit 1
fi

# GitHubトークンの確認（複数の可能性をチェック）
if [ -n "$GITHUB_TOKEN" ]; then
    echo "Using GITHUB_TOKEN"
elif [ -n "$CIRCLE_TOKEN" ]; then
    echo "Using CIRCLE_TOKEN as GITHUB_TOKEN"
    GITHUB_TOKEN="$CIRCLE_TOKEN"
elif [ -n "$GH_TOKEN" ]; then
    echo "Using GH_TOKEN as GITHUB_TOKEN" 
    GITHUB_TOKEN="$GH_TOKEN"
else
    echo "Error: No GitHub token found (GITHUB_TOKEN, CIRCLE_TOKEN, or GH_TOKEN)"
    exit 1
fi

# PR情報を取得
if [ -z "$CIRCLE_PULL_REQUEST" ]; then
    echo "No PR URL found, skipping PR summary generation"
    exit 0
fi

# CIRCLE_PULL_REQUESTからPR番号を抽出
# 例: https://github.com/otajisan/automated-code-review-on-circleci/pull/2 -> 2
PR_NUMBER=$(echo "$CIRCLE_PULL_REQUEST" | sed 's|.*/pull/||')

if [ -z "$PR_NUMBER" ] || ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Failed to extract valid PR number from: $CIRCLE_PULL_REQUEST"
    exit 1
fi

echo "# Generating summary for PR #${PR_NUMBER}"

# git diffで変更内容を取得
DIFF_OUTPUT=$(git diff origin/main...HEAD)

echo "# Diff Output:"
echo "$DIFF_OUTPUT"

# Claude Codeでサマリを生成
PROMPT="以下のコード変更を分析して、分かりやすい日本語でPRサマリを作成してください：

変更内容：
${DIFF_OUTPUT}

以下の形式で出力してください：
## 変更概要
## 主な変更点
## 影響範囲
## 注意事項（あれば）"

echo '# Checking claude command...'
echo "Debug: About to run claude command"
echo "ANTHROPIC_API_KEY is set: $([ -n "$ANTHROPIC_API_KEY" ] && echo "yes" || echo "no")"
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Claude command path: $(which claude)"
echo "Claude version: $(claude --version 2>&1 || echo "version check failed")"

echo '# Creating PR summary with Claude...'

# Claude Codeを実行してサマリ生成
which claude

echo '# Running claude command with CI environment...'
export CI=true
export NODE_ENV=production

# 非対話的環境でClaude CLIを使用
echo "# Using Claude CLI in non-interactive mode..."

# 環境変数を設定して非対話的モードにする
export CLAUDE_NO_INTERACTIVE=true
export CLAUDE_NO_TUI=true

# プロンプトをファイルに書き込んで使用
echo "$PROMPT" > /tmp/claude_prompt.txt

# Claude CLIを非対話的モードで実行
SUMMARY=$(timeout 30 claude /tmp/claude_prompt.txt 2>/dev/null || echo "Claude CLIの実行に失敗しました。手動でレビューしてください。")

# ファイルを削除
rm -f /tmp/claude_prompt.txt

echo '# Saving PR summary to /tmp/pr_summary.json'
echo "{\"body\":\"🤖 **自動生成されたPRサマリ**\\n\\n${SUMMARY}\"}" > /tmp/pr_summary.json

echo "# Generated PR Summary:"
cat /tmp/pr_summary.json

echo "# Checking GitHub API credentials..."
echo "GITHUB_TOKEN is set: $([ -n "$GITHUB_TOKEN" ] && echo "yes" || echo "no")"
echo "CIRCLE_PROJECT_USERNAME: $CIRCLE_PROJECT_USERNAME"
echo "CIRCLE_PROJECT_REPONAME: $CIRCLE_PROJECT_REPONAME"

echo "# Posting summary to PR #${PR_NUMBER}"
# GitHub APIでPRにコメントを投稿
GITHUB_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/${PR_NUMBER}/comments" \
  -d "{\"body\":\"🤖 **自動生成されたPRサマリ**\\n\\n${SUMMARY}\"}")

echo "# GitHub API Response:"
echo "$GITHUB_RESPONSE"

echo "# PR summary generated and posted successfully!"
