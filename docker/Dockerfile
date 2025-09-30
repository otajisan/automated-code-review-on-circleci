FROM cimg/node:22.20

RUN sudo apt-get update && sudo apt-get install -y \
    git \
    curl \
    ca-certificates \
    && sudo rm -rf /var/lib/apt/lists/*

# install github CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt-get update \
    && sudo apt-get install gh -y

WORKDIR /claude-code-docker

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# git configuration
RUN git config --global user.email "ci@example.com" && \
    git config --global user.name "Circle CI"

COPY scripts/ ./scripts/
RUN sudo chmod +x ./scripts/*.sh

CMD ["bash"]
