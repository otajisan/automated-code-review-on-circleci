#!/bin/bash
# scripts/generate-pr-summary.sh

set -e

# 環境変数チェック
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY is not set"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN is not set"
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

echo "Generating summary for PR #${PR_NUMBER}"

# git diffで変更内容を取得
DIFF_OUTPUT=$(git diff origin/main...HEAD)

echo "Diff Output:"
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

# Claude Codeを実行してサマリ生成
SUMMARY=$(claude "$PROMPT")

echo "{\"body\":\"🤖 **自動生成されたPRサマリ**\\n\\n${SUMMARY}\"}" > /tmp/pr_summary.json

echo "Generated PR Summary:"
cat /tmp/pr_summary.json

# GitHub APIでPRにコメントを投稿
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/${PR_NUMBER}/comments" \
  -d '{"body": "this is test comment"}'
  #-d "{\"body\":\"🤖 **自動生成されたPRサマリ**\\n\\n${SUMMARY}\"}"

echo "PR summary generated and posted successfully!"
