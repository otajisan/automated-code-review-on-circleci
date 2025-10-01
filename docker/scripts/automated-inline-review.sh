#!/bin/bash
# scripts/automated-inline-review.sh
# Pull Requestの各コード行にインラインレビューコメントを投稿するスクリプト

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 環境変数チェック
"${SCRIPT_DIR}/verify-api-tokens.sh"

# PR情報を取得
if [ -z "$CIRCLE_PULL_REQUEST" ]; then
    echo "No PR URL found, skipping inline code review"
    exit 0
fi

# CIRCLE_PULL_REQUESTからPR番号を抽出
PR_NUMBER=$(echo "$CIRCLE_PULL_REQUEST" | sed 's|.*/pull/||')

if [ -z "$PR_NUMBER" ] || ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Failed to extract valid PR number from: $CIRCLE_PULL_REQUEST"
    exit 1
fi

echo "# Checking if automated inline review already exists for PR #${PR_NUMBER}"

# GitHub APIでPRのレビューコメントを確認
EXISTING_REVIEW_COMMENTS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/pulls/${PR_NUMBER}/comments")

# 既存の自動インラインレビューがあるかチェック
EXISTING_AUTO_INLINE_REVIEW=$(echo "$EXISTING_REVIEW_COMMENTS" | jq -r '.[] | select(.body | contains("🤖 自動インラインレビュー")) | .created_at' | head -1)

if [ -n "$EXISTING_AUTO_INLINE_REVIEW" ] && [ "$EXISTING_AUTO_INLINE_REVIEW" != "null" ]; then
    echo "# Automated inline review already exists (created at: $EXISTING_AUTO_INLINE_REVIEW) for PR #${PR_NUMBER}. Skipping generation."
    exit 0
fi

echo "# No existing automated inline review found. Starting automated inline review for PR #${PR_NUMBER}"

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

echo "# Generating inline code review with Claude..."

# インラインレビュー用のプロンプト
INLINE_REVIEW_PROMPT="あなたは経験豊富なコードレビュアーです。以下のコード変更を詳細にレビューし、具体的な問題箇所に対してインラインコメントを提供してください。

変更されたファイル:
${CHANGED_FILES}

詳細な変更内容:
${DETAILED_DIFF}

以下の形式でレビューを行ってください：

## INLINE_COMMENTS
具体的なコード行に対する問題があれば、以下の形式で出力してください：
FILE: ファイルパス
LINE: 行番号
COMMENT: 具体的な問題点と改善提案

例：
FILE: src/example.js
LINE: 25
COMMENT: この箇所でnullチェックが不足しています。variableがnullの場合にエラーが発生する可能性があります。

FILE: src/example.js
LINE: 42
COMMENT: パフォーマンスの観点から、このループ処理はMap.get()よりもfilter()を使用することを推奨します。

## GENERAL_FEEDBACK
全体的なフィードバックやインラインコメントできない内容：
- この変更全体の品質評価
- アーキテクチャレベルの改善提案
- テストやドキュメントの必要性

具体的で建設的なフィードバックを心がけ、特に潜在的なバグ、セキュリティ問題、パフォーマンス問題、コードの可読性に重点を置いてください。"

# Claude CLIでインラインレビューを生成
export CI=true
export NODE_ENV=production
export CLAUDE_NO_INTERACTIVE=true
export CLAUDE_NO_TUI=true

echo "# Running Claude inline review..."
CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-60}
if ! INLINE_REVIEW_RESULT=$(echo "$INLINE_REVIEW_PROMPT" | timeout "$CLAUDE_TIMEOUT" claude 2>&1); then
    echo "Warning: Claude CLI execution failed after ${CLAUDE_TIMEOUT}s timeout: $INLINE_REVIEW_RESULT" >&2
    INLINE_REVIEW_RESULT="⚠️ インラインレビューの生成に失敗しました。手動でレビューしてください。"
fi

echo "# Inline review generated successfully"
echo "# Review content:"
echo "$INLINE_REVIEW_RESULT"

# レビュー結果を解析してインラインコメントと一般フィードバックに分離
echo "$INLINE_REVIEW_RESULT" > /tmp/review_result.txt

# インラインコメント部分を抽出
INLINE_COMMENTS=$(sed -n '/## INLINE_COMMENTS/,/## GENERAL_FEEDBACK/p' /tmp/review_result.txt | sed '1d;$d')
# 一般フィードバック部分を抽出
GENERAL_FEEDBACK=$(sed -n '/## GENERAL_FEEDBACK/,$p' /tmp/review_result.txt | sed '1d')

echo "# Processing inline comments..."

# PRの最新コミットSHAを取得
LATEST_COMMIT_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/pulls/${PR_NUMBER}" | \
  jq -r '.head.sha')

echo "# Latest commit SHA: $LATEST_COMMIT_SHA"

# インラインコメントを処理
echo "$INLINE_COMMENTS" | while IFS= read -r line; do
    if [[ "$line" =~ ^FILE:\ (.+)$ ]]; then
        CURRENT_FILE="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^LINE:\ ([0-9]+)$ ]]; then
        CURRENT_LINE="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^COMMENT:\ (.+)$ ]]; then
        CURRENT_COMMENT="🤖 自動インラインレビュー

${BASH_REMATCH[1]}

---
*このコメントはClaude AIによって自動生成されました*"
        
        if [ -n "$CURRENT_FILE" ] && [ -n "$CURRENT_LINE" ] && [ -n "$CURRENT_COMMENT" ]; then
            echo "# Posting inline comment for ${CURRENT_FILE}:${CURRENT_LINE}"
            
            # インラインコメント用のJSONを生成
            jq -n \
              --arg body "$CURRENT_COMMENT" \
              --arg path "$CURRENT_FILE" \
              --arg commit_id "$LATEST_COMMIT_SHA" \
              --argjson line "$CURRENT_LINE" \
              '{
                body: $body,
                path: $path,
                commit_id: $commit_id,
                line: $line,
                side: "RIGHT"
              }' > /tmp/inline_comment.json
            
            # GitHub APIでインラインコメントを投稿
            GITHUB_RESPONSE=$(curl -s -X POST \
              -H "Authorization: token $GITHUB_TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              -H "Content-Type: application/json" \
              "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/pulls/${PR_NUMBER}/comments" \
              -d @/tmp/inline_comment.json)
            
            # エラーチェック
            if echo "$GITHUB_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
                ERROR_MSG=$(echo "$GITHUB_RESPONSE" | jq -r '.message')
                echo "# Warning: Failed to post inline comment for ${CURRENT_FILE}:${CURRENT_LINE} - $ERROR_MSG"
            else
                echo "# Successfully posted inline comment for ${CURRENT_FILE}:${CURRENT_LINE}"
            fi
        fi
        
        # 変数をクリア
        CURRENT_FILE=""
        CURRENT_LINE=""
        CURRENT_COMMENT=""
    fi
done

# 一般フィードバックがある場合は通常のコメントとして投稿
if [ -n "$GENERAL_FEEDBACK" ] && [ "$GENERAL_FEEDBACK" != "" ]; then
    echo "# Posting general feedback as PR comment..."
    
    GENERAL_COMMENT="## 🤖 自動コードレビュー（全体評価）

${GENERAL_FEEDBACK}

---
*このレビューはClaude AIによって自動生成されました*"
    
    echo "$GENERAL_COMMENT" | jq -Rs '{"body": .}' > /tmp/general_comment.json
    
    curl -s -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/${PR_NUMBER}/comments" \
      -d @/tmp/general_comment.json
    
    echo "# General feedback posted successfully"
fi

echo "# Automated inline code review completed!"