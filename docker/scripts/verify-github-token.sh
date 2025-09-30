#!/bin/bash
# scripts/verify-github-token.sh

set -e

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
