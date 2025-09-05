FROM node:22-slim

RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# install github CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh -y

WORKDIR /claude-code-docker

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# git configuration
RUN git config --global user.email "ci@example.com" && \
    git config --global user.name "Circle CI"

COPY scripts/ ./scripts/
RUN chmod +x ./scripts/*.sh

CMD ["bash"]
