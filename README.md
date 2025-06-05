# 🎯 faff

> **Drop the faff from your Git commits!**

Automatically generate **conventional commit messages** from your git diffs using the power of local LLMs via Ollama. No more staring at staged changes wondering how to summarize them – let AI craft commit messages that follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) standards.

## ✨ Why faff?

There are plenty of AI git commit message generators, they mostly rely on cloud APIs. `faff` was born from a desire to explore the [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md) while creating a privacy-first alternative that keeps your code local. It's a learning project that became genuinely useful!

- **🤖 AI-Powered**: Leverages local Ollama LLMs for intelligent commit message generation
- **📝 Standards-Compliant**: Automatically follows Conventional Commits specification
- **️🕵️ Privacy-First**: Runs entirely locally - your code never leaves your machine
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

# 🧠 AI Models

I've mostly tested `faff` using the [**qwen2.5-coder**](https://ollama.com/library/qwen2.5-coder) family of models as they've worked best in my test. Choose one based on your available VRAM/Unified memory:

| Model                  | VRAM  | Speed | Quality    |
|------------------------|-------|-------|------------|
| `qwen2.5-coder:1.5b`   | ~1GB  | ⚡⚡⚡⚡  | ⭐⭐       |
| `qwen2.5-coder:3b`     | ~2GB  | ⚡⚡⚡   | ⭐⭐⭐     |
| **`qwen2.5-coder:7b`** | ~5GB  | ⚡⚡⚡   | ⭐⭐⭐⭐   |
| `qwen2.5-coder:14b`    | ~9GB  | ⚡⚡    | ⭐⭐⭐⭐⭐ |
| `qwen2.5-coder:32b`    | ~20GB | ⚡     | ⭐⭐⭐⭐⭐ |

Any model supported by Ollama will work so feel free to experiment 🧪 Share your feedback and observations in the [`faff` discussions](https://github.com/wimpysworld/faff/discussions) ️🗨️ so we can all benefit.

## Using a Custom Model

To use a specific model, just override the `FAFF_MODEL` environment variable.

```bash
FAFF_MODEL="qwen2.5-coder:3b" faff
```

### Environment Variables

Customize `faff`'s behavior through environment variables:

```bash
# Model selection (default: qwen2.5-coder:7b)
export FAFF_MODEL="qwen2.5-coder:14b"

# Ollama connection (defaults to localhost:11434)
export OLLAMA_HOST="your-ollama-server.com"
export OLLAMA_PORT="11434"

# API timeout in seconds (default: 180)
export FAFF_TIMEOUT=300
```

### Shell Configuration

Add to your shell profile for persistent settings:

```bash
# ~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish
export FAFF_MODEL="qwen2.5-coder:7b"
export OLLAMA_HOST="localhost"
export OLLAMA_PORT="11434"
export FAFF_TIMEOUT=180
```

# 🐙 Git Integration

Add helpful aliases to your `~/.gitconfig`:

```bash
[alias]
    faff = "!faff"               # Generate commit with faff
    yolo = "!git add . && faff"  # Stage all and commit with faff
```

# 🛟 Troubleshooting

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