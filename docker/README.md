# Claude Code Docker Image

A lightweight Docker image with Claude Code pre-installed for CI/CD automation and development workflows.

## Overview

This image is built on Node.js 18 slim and includes Claude Code CLI, Git, and GitHub CLI for seamless integration with CI/CD pipelines. Perfect for automated Pull Request analysis, code reviews, and other AI-powered development tasks.

## Features

- ✅ **Claude Code CLI** pre-installed and ready to use
- ✅ **Git** for repository operations  
- ✅ **GitHub CLI** for GitHub API interactions
- ✅ **Node.js 22** runtime environment
- ✅ **Minimal footprint** based on slim base image
- ✅ **CI/CD optimized** for Circle CI, GitHub Actions, and other platforms
- ✅ **Automated PR Summary Generation** with size limits and error handling
- ✅ **Security-focused** with no token leakage in logs
- ✅ **Configurable timeouts** and diff size limits

## Quick Start

```bash
# Pull the image
docker pull otajisan/claude-code-docker:latest

# Run interactively
docker run -it --rm \
  -e ANTHROPIC_API_KEY=your_api_key \
  -v $(pwd):/workspace \
  -w /workspace \
  otajisan/claude-code-docker:latest bash

# Execute Claude Code directly
docker run --rm \
  -e ANTHROPIC_API_KEY=your_api_key \
  -v $(pwd):/workspace \
  -w /workspace \
  otajisan/claude-code-docker:latest \
  claude-code --help
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | ✅ | - | Your Anthropic API key for Claude access |
| `GITHUB_TOKEN` | ⚠️ | - | GitHub Personal Access Token (required for GitHub operations) |
| `MAX_DIFF_SIZE` | ❌ | 50000 | Maximum git diff size in bytes to prevent API timeouts |
| `CLAUDE_TIMEOUT` | ❌ | 30 | Timeout in seconds for Claude CLI operations |
| `CLAUDE_NO_INTERACTIVE` | ❌ | true | Disable interactive mode for CI environments |
| `CLAUDE_NO_TUI` | ❌ | true | Disable TUI interface for CI environments |

## Usage Examples

### Circle CI Integration

```yaml
version: 2.1

jobs:
  claude-automation:
    docker:
      - image: otajisan/claude-code-docker:latest
    steps:
      - checkout
      - run:
          name: "Generate PR Summary"
          command: claude "Analyze this PR..."
          environment:
            ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY
```

### GitHub Actions Integration

```yaml
jobs:
  claude-review:
    runs-on: ubuntu-latest
    container:
      image: otajisan/claude-code-docker:latest
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
    steps:
      - uses: actions/checkout@v3
      - run: claude --version
```

### Local Development

```bash
# Mount your project and run Claude Code
docker run --rm -it \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -v $(pwd):/app \
  -w /app \
  otajisan/claude-code-docker:latest \
  claude "Review this code change"
```

## Volume Mounts

Mount your project directory to work with your code:

```bash
-v /path/to/your/project:/workspace
-w /workspace
```

## Automated Scripts

### PR Summary Generation

The `generate-pr-summary.sh` script automatically:
- Extracts PR changes using git diff
- Generates AI-powered summaries using Claude
- Posts summaries as PR comments
- Handles large diffs with size limits
- Provides proper error handling and logging
- **Prevents duplicate summaries** - only generates once per PR
- Checks for existing summaries before generating new ones

### Code Review Automation

The `automated-code-review.sh` script provides:
- Comprehensive code analysis
- Security vulnerability detection
- Performance recommendations
- Best practice suggestions
- **Duplicate review prevention** - only reviews once per PR
- Checks for existing reviews before generating new ones

## Cost Considerations

**Claude API Usage Estimates:**
- Small PR (< 1KB diff): ~$0.01 per summary
- Medium PR (5KB diff): ~$0.03 per summary  
- Large PR (50KB diff): ~$0.15 per summary

*Costs are approximate and depend on Claude model usage and token consumption.*

## Security Considerations

- 🔐 Store API keys securely using your CI/CD platform's secrets management
- 🔒 Use least-privilege GitHub tokens when possible
- 🛡️ Regularly update the base image for security patches
- 🔒 Token information is not exposed in logs for security
- ⚠️ Diff content may contain sensitive information - ensure proper access controls

## Troubleshooting

### Common Issues

**Claude Code not found:**
```bash
# Check if Claude Code is properly installed
docker run --rm otajisan/claude-code-docker:latest which claude
```

**Permission errors:**
```bash
# Ensure proper file permissions
docker run --rm -v $(pwd):/workspace otajisan/claude-code-docker:latest ls -la /workspace
```

**API key issues:**
```bash
# Verify API key is set
docker run --rm -e ANTHROPIC_API_KEY=test otajisan/claude-code-docker:latest env | grep ANTHROPIC
```

## Version Information

- **Base Image**: node:22-slim
- **Claude Code**: Latest stable version
- **GitHub CLI**: Latest stable version
- **Git**: Latest from apt repositories

## Support

- 📖 [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)

## License

This Docker image is provided under the MIT License. Claude Code itself is subject to Anthropic's terms of service.

---

**⚠️ Important**: This image requires a valid Anthropic API key. Make sure you have proper billing and usage limits configured for your Anthropic account.
