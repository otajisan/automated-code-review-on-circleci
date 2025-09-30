#!/bin/bash
# scripts/automated-code-review.sh

set -e

# 環境変数チェック
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY is not set"
    exit 1
fi

echo "# Testing Anthropic API key..."
echo "API Key format: ${ANTHROPIC_API_KEY:0:10}...${ANTHROPIC_API_KEY: -4}"

# APIキーの簡単なテスト
API_TEST=$(curl -s -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -d '{"model": "claude-3-5-sonnet-20241022", "max_tokens": 10, "messages": [{"role": "user", "content": "test"}]}' \
  | jq -r '.type' 2>/dev/null)

if [ "$API_TEST" = "error" ]; then
    echo "Warning: Anthropic API key appears to be invalid"
    exit 1
elif [ "$API_TEST" = "message" ]; then
    echo "Success: Anthropic API key is valid"
else
    echo "Unknown API response: $API_TEST"
fi

# GitHubトークンの確認
if [ -n "$GITHUB_TOKEN" ]; then
    echo "Using GITHUB_TOKEN"
elif [ -n "$CIRCLE_TOKEN" ]; then
    echo "Using CIRCLE_TOKEN as GITHUB_TOKEN"
    GITHUB_TOKEN="$CIRCLE_TOKEN"
elif [ -n "$GH_TOKEN" ]; then
    echo "Using GH_TOKEN as GITHUB_TOKEN"
    GITHUB_TOKEN="$GH_TOKEN"
else
    echo "Error: No GitHub token found"
    exit 1
fi

# PR情報を取得
if [ -z "$CIRCLE_PULL_REQUEST" ]; then
    echo "No PR URL found, skipping code review"
    exit 0
fi

# CIRCLE_PULL_REQUESTからPR番号を抽出
PR_NUMBER=$(echo "$CIRCLE_PULL_REQUEST" | sed 's|.*/pull/||')

if [ -z "$PR_NUMBER" ] || ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Failed to extract valid PR number from: $CIRCLE_PULL_REQUEST"
    exit 1
fi

echo "# Starting automated code review for PR #${PR_NUMBER}"

# 変更されたファイル一覧を取得
CHANGED_FILES=$(git diff --name-only origin/main...HEAD)
echo "# Changed files:"
echo "$CHANGED_FILES"

# 各ファイルの詳細な差分を取得
DETAILED_DIFF=$(git diff origin/main...HEAD)

echo "# Generating code review with Claude..."

# コードレビュー用のプロンプト
REVIEW_PROMPT="あなたは経験豊富なコードレビュアーです。以下のコード変更をレビューしてください。

変更されたファイル:
${CHANGED_FILES}

詳細な変更内容:
${DETAILED_DIFF}

以下の観点でレビューを行い、日本語で出力してください：

## 🎯 全体的な評価
- この変更の品質を5段階で評価
- 良い点を2-3点

## 🔍 指摘事項
- 潜在的なバグやエラーハンドリングの問題
- パフォーマンスへの懸念
- セキュリティ上の問題
- コードの可読性や保守性

## ✅ 推奨事項
- 改善提案（具体的なコード例があれば尚良い）
- ベストプラクティスの適用

## 📝 その他のコメント
- テストの必要性
- ドキュメント更新の必要性

建設的で具体的なフィードバックを心がけてください。"

# Claude CLIでコードレビューを生成
export CI=true
export NODE_ENV=production
export CLAUDE_NO_INTERACTIVE=true
export CLAUDE_NO_TUI=true

echo "# Running Claude code review..."
REVIEW_RESULT=$(echo "$REVIEW_PROMPT" | timeout 60 claude 2>/dev/null || echo "⚠️ コードレビューの生成に失敗しました。手動でレビューしてください。")

echo "# Code review generated successfully"
echo "# Review content:"
echo "$REVIEW_RESULT"

# GitHub Review Comment用のJSONを生成
REVIEW_BODY="## 🤖 自動コードレビュー

${REVIEW_RESULT}

---
*このレビューはClaude AIによって自動生成されました*"

echo "$REVIEW_BODY" | jq -Rs '{"body": ., "event": "COMMENT"}' > /tmp/code_review.json

echo "# Generated review JSON:"
cat /tmp/code_review.json

# GitHub APIでPRレビューを投稿
echo "# Posting review to PR #${PR_NUMBER}"
GITHUB_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/pulls/${PR_NUMBER}/reviews" \
  -d @/tmp/code_review.json)

echo "# GitHub API Response:"
echo "$GITHUB_RESPONSE" | jq '.'

# エラーチェック
if echo "$GITHUB_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$GITHUB_RESPONSE" | jq -r '.message')
    echo "# Error posting review: $ERROR_MSG"

    # フォールバック: 通常のコメントとして投稿
    echo "# Falling back to regular comment..."
    echo "$REVIEW_BODY" | jq -Rs '{"body": .}' > /tmp/code_review_comment.json

    curl -s -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/${PR_NUMBER}/comments" \
      -d @/tmp/code_review_comment.json

    echo "# Review posted as comment instead"
else
    echo "# Code review posted successfully!"
fi
