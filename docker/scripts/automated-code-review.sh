#!/bin/bash
# scripts/automated-code-review.sh
# Pull Requestに対して統合的な自動コードレビューを実行するメインスクリプト

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 環境変数チェック
"${SCRIPT_DIR}/verify-api-tokens.sh"

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

echo "# Checking if automated code review already exists for PR #${PR_NUMBER}"

# GitHub APIでPRのレビューを確認
EXISTING_REVIEWS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/pulls/${PR_NUMBER}/reviews")

# 既存の自動レビューがあるかチェック
EXISTING_AUTO_REVIEW=$(echo "$EXISTING_REVIEWS" | jq -r '.[] | select(.body | contains("🤖 自動コードレビュー")) | .submitted_at' | head -1)

if [ -n "$EXISTING_AUTO_REVIEW" ] && [ "$EXISTING_AUTO_REVIEW" != "null" ]; then
    echo "# Automated code review already exists (submitted at: $EXISTING_AUTO_REVIEW) for PR #${PR_NUMBER}. Skipping generation."
    exit 0
fi

echo "# No existing automated review found. Starting automated code review for PR #${PR_NUMBER}"

# 変更されたファイル一覧を取得
CHANGED_FILES=$(git diff --name-only origin/main...HEAD)
echo "# Changed files:"
echo "$CHANGED_FILES"

# 各ファイルの詳細な差分を取得（サイズ制限付き）
DETAILED_DIFF=$(git diff origin/main...HEAD)
DIFF_SIZE=${#DETAILED_DIFF}
MAX_DIFF_SIZE=${MAX_DIFF_SIZE:-50000}  # デフォルト50KB

echo "# Diff size: $DIFF_SIZE bytes"

if [ "$DIFF_SIZE" -gt "$MAX_DIFF_SIZE" ]; then
    echo "Warning: Diff size ($DIFF_SIZE bytes) exceeds limit ($MAX_DIFF_SIZE bytes). Truncating..." >&2
    DETAILED_DIFF=$(echo "$DETAILED_DIFF" | head -c "$MAX_DIFF_SIZE")
    DETAILED_DIFF="${DETAILED_DIFF}

... (diff truncated due to size limit)"
fi

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
CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-60}
if ! REVIEW_RESULT=$(echo "$REVIEW_PROMPT" | timeout "$CLAUDE_TIMEOUT" claude 2>&1); then
    echo "Warning: Claude CLI execution failed after ${CLAUDE_TIMEOUT}s timeout: $REVIEW_RESULT" >&2
    REVIEW_RESULT="⚠️ コードレビューの生成に失敗しました。手動でレビューしてください。"
fi

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

echo "# Starting inline code review..."

# インラインレビューを実行
"${SCRIPT_DIR}/automated-inline-review.sh"

echo "# Automated code review process completed!"
