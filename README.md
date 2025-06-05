# 🎯 faff

> **Drop the faff from your Git commits!**

Automatically generate **conventional commit messages** from your git diffs using the power of local LLMs via Ollama. No more staring at staged changes wondering how to summarize them – let AI craft commit messages that follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) standards.

## ✨ Why faff?

There are plenty AI commit tools, they mostly rely on cloud APIs. `faff` was born from a desire to explore the [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md) while creating a privacy-first alternative that keeps your code local. It's a learning project that became genuinely useful!

- **🤖 AI-Powered**: Leverages local Ollama LLMs for intelligent commit message generation
- **📝 Standards-Compliant**: Automatically follows Conventional Commits specification
- **🔒 Privacy-First**: Runs entirely locally - your code never leaves your machine
- **🐤 Simple Setup**: Auto-downloads models and handles all dependencies
- **🎨 Beautiful UX**: Elegant progress indicators and interactive prompts

# 🚀 Quick Start

## Prerequisites

- **Ollama** installed and running ([get it here](https://ollama.ai/))
  - Can be a remote instance
- `bc`, `curl` and `jq`
- A **git repository** with staged changes

## Install

Download `faff`, make it executable and put it somewhere in your `$PATH`.

```bash
curl -o faff.sh https://raw.githubusercontent.com/wimpysworld/faff/refs/heads/main/faff.sh
chmod +x faff.sh
sudo mv faff.sh /usr/local/bin/faff
```

## Basic Usage

The standard workflow is stage some changes and let `faff` generate your commit message.

```bash
git add .
faff
```

That's it! `faff` will analyze your changes and generate a commit message.

<!-- [Screenshot: Show the faff interface with spinner animation and generated commit message preview] -->

# ⚙️ Configuration

## Environment Variables

Customize faff's behavior through environment variables:

```bash
# Model selection (default: qwen2.5-coder:7b)
export OLLAMA_MODEL="qwen2.5-coder:14b"

# Ollama connection (defaults to localhost:11434)
export OLLAMA_HOST="your-ollama-server.com"
export OLLAMA_PORT="11434"

# API timeout in seconds (default: 180)
export TIMEOUT=300
```

## Shell Configuration

Add to your shell profile for persistent settings:

```bash
# ~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish
export OLLAMA_MODEL="qwen2.5-coder:7b"
export OLLAMA_HOST="localhost"
export OLLAMA_PORT="11434"
export TIMEOUT=180
```

## Git Integration

Add helpful aliases to your `~/.gitconfig`:

```bash
[alias]
    faff = "!faff.sh"                # Generate commit with faff
    yolo = "!git add . && faff.sh"   # Stage all and commit with faff
```

## Recommended Models

faff works best with the **qwen2.5-coder** family. Choose based on your available VRAM:

| Model                | VRAM  | Speed | Quality    |
|----------------------|-------|-------|------------|
| `qwen2.5-coder:1.5b` | ~1GB  | ⚡⚡⚡⚡  | ⭐⭐       |
| `qwen2.5-coder:3b`   | ~2GB  | ⚡⚡⚡   | ⭐⭐⭐     |
| `qwen2.5-coder:7b`   | ~5GB  | ⚡⚡⚡   | ⭐⭐⭐⭐   |
| `qwen2.5-coder:14b`  | ~9GB  | ⚡⚡    | ⭐⭐⭐⭐⭐ |
| `qwen2.5-coder:32b`  | ~20GB | ⚡     | ⭐⭐⭐⭐⭐ |

### Using a Custom Model

```bash
# Use a specific model based on your GPU memory
OLLAMA_MODEL="qwen2.5-coder:3b" faff
```

# 🐛 Troubleshooting

## Common Issues

**❌ "Ollama service is not running"**

Start Ollama.

```bash
ollama serve
```

**❌ "No changes to commit"**

Stage some changes first.

```bash
git add .
```

# 🤝 Contributing

We welcome contributions! Whether you're fixing bugs, adding features, or improving documentation, your help makes `faff` better for everyone.