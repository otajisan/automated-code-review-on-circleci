#!/bin/bash
# scripts/verify-api-tokens.sh
# 共通の環境変数チェック処理

set -e

echo "# Verifying Claude Code configuration..."

# Anthropic API キーのチェック
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY is not set"
    exit 1
fi

echo "API Key is configured: $([ -n "$ANTHROPIC_API_KEY" ] && echo "yes" || echo "no")"

# GitHubトークンの確認（複数の可能性をチェック）
if [ -n "$GITHUB_TOKEN" ]; then
    echo "Using GITHUB_TOKEN"
elif [ -n "$CIRCLE_TOKEN" ]; then
    echo "Using CIRCLE_TOKEN as GITHUB_TOKEN"
    export GITHUB_TOKEN="$CIRCLE_TOKEN"
elif [ -n "$GH_TOKEN" ]; then
    echo "Using GH_TOKEN as GITHUB_TOKEN"
    export GITHUB_TOKEN="$GH_TOKEN"
else
    echo "Error: No GitHub token found (GITHUB_TOKEN, CIRCLE_TOKEN, or GH_TOKEN)"
    exit 1
fi

# Claude CLI の動作確認
echo "# Checking Claude CLI..."
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Claude command path: $(which claude)"
echo "Claude version: $(claude --version 2>&1 || echo "version check failed")"

echo "# Environment verification completed successfully"
