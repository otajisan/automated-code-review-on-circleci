#!/bin/bash
# scripts/verify-claude-code-token.sh

set -e

# 環境変数チェック
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY is not set"
    exit 1
fi

echo "# Testing Anthropic API key..."
# APIキーの最初の10文字と最後の4文字を表示（セキュリティのため）
echo "API Key format: ${ANTHROPIC_API_KEY:0:10}...${ANTHROPIC_API_KEY: -4}"
