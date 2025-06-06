# 🎯 faff

> **Drop the faff, dodge the judgment, get back to coding.**

Stop staring at that staged diff like it owes you money. We all know the drill: you've made brilliant changes, `git` knows exactly what happened, but translating that into a proper [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) message feels like explaining your code to your pets 🐾 `faff` uses local LLMs via [Ollama](https://ollama.com/) to automatically generate commit messages from your diffs – because your changes already tell the story, they just need a translator that speaks developer ‍🧑‍💻

`faff` is a productivity tool for the mundane stuff, not a replacement for thoughtful communication.

## ✨ Why faff?

We've all been there: you spend longer crafting the commit message than writing the actual code. "Was that a `feat:` or `fix:`?" you wonder, as your staged diff sits there perfectly describing everything while you faff about trying to translate it into prose.

You either end up with "Updated stuff" (*again!*) or some overwrought novel nobody will read. Meanwhile, cloud-based tools want to slurp up your "TODO: delete this abomination" comments and questionable variable names all while extracting money from your wallet 💸

`faff` exists because your diffs already know what happened – they just need a local AI translator that follows conventional commits rules without the existential crisis. **Drop the faff, dodge the judgment, get back to coding.**

So yes, `faff` is another bloody AI commit generator. The Internet's already drowning in them, so here's another one to add to the deluge of "my first AI projects" 💧 `faff` started as me having a poke around the [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md) while thinking "surely we can do this locally without sending the content of our wallets to the vibe-coding dealers?" It's basically a learning project that accidentally became useful – like most of the best tools, really.

- **🤖 AI-Powered**: Uses local Ollama LLMs for *"intelligent"* commit message generation
- **📝 Standards-Compliant**: Follows Conventional Commits specification, most of the time if you're lucky
- **️🕵️ Privacy-First**: Runs entirely locally - your code never leaves your machine, until you push it to GitHub
- **🐤 Simple Setup**: Auto-downloads models and handles all dependencies, except it doesn't - that was a marketing lie
- **🎨 Beautiful UX**: Elegant progress indicators and interactive prompts, for a shell script

# 🚀 Quick Start

## Prerequisites

- [**Ollama**](https://ollama.ai/) installed and running somewhere
- [coreutils](https://www.gnu.org/software/coreutils/) or [uutils/coreutils](https://github.com/uutils/coreutils)
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

<div align="center"><img alt="faff demo" src="assets/faff.gif" width="1024" /></div>

# 🧠 AI Models

I've mostly tested `faff` using the [**qwen2.5-coder**](https://ollama.com/library/qwen2.5-coder) family of models as they've worked best during my testing. Choose one based on your available VRAM or Unified memory:

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
    vibe = "!git add . && faff"  # Stage all and commit with faff
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

## macOS Issues

❌ timeout: command not found

Install GNU coreutils

```sh
brew install coreutils
```

# 🤝 Contributing

We welcome contributions! Whether you're fixing bugs, adding features, or improving documentation, your help makes `faff` better for everyone.