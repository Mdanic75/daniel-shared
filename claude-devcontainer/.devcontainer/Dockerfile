FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Claude Code for vscode, from the native installer. The config directory is created first,
# so its volume comes up owned by vscode, and set before the installer runs, so the installer
# writes .claude.json into it.
USER vscode
RUN mkdir -p /home/vscode/.claude
ENV CLAUDE_CONFIG_DIR=/home/vscode/.claude
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/vscode/.local/bin:$PATH
