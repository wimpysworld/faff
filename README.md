# 🎯 faff

> **Drop the faff, dodge the judgment, get back to coding.**

Stop staring at that staged diff like it owes you money. We all know the drill: you've made brilliant changes, `git` knows exactly what happened, but translating that into a proper [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) message feels like explaining your code to your pets 🐾

`faff` uses local LLMs via [Ollama](https://ollama.com/) to automatically generate commit messages from your diffs – because your changes already tell the story, they just need a translator that speaks developer 🧑‍💻

This is the **Go implementation** of faff, rewritten from the original Bash script for better performance, error handling, and maintainability.

## ✨ Why Go?

The original `faff.sh` was a proper Bash script, but it had grown beyond what shell scripting handles elegantly:

- **Complex JSON manipulation** - Go's native JSON support beats jq gymnastics
- **HTTP client operations** - Proper timeout handling, retries, and error context
- **Concurrent operations** - Better spinner handling without background process juggling
- **Error handling** - Explicit error propagation instead of hoping `set -e` catches everything
- **Cross-platform compatibility** - No more worrying about GNU vs BSD coreutils
- **Type safety** - Catch configuration errors at compile time, not runtime
- **Testing** - Proper unit tests instead of hoping for the best

## 🚀 Quick Start

### Prerequisites

- [**Ollama**](https://ollama.ai/) installed and running
- **Go 1.21+** for building from source
- A **git repository** with staged changes

### Install from Source

```bash
git clone https://github.com/wimpysworld/faff.git
cd faff
make install
```

### Install from Release

Download the appropriate binary for your platform from the [releases page](https://github.com/wimpysworld/faff/releases):

```bash
# Linux/macOS
curl -L -o faff https://github.com/wimpysworld/faff/releases/latest/download/faff-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
chmod +x faff
sudo mv faff /usr/local/bin/
```

### Basic Usage

The standard workflow remains the same - stage some changes and let `faff` generate your commit message:

```bash
git add .
faff
```

That's it! `faff` will analyze your changes and generate a commit message.

## 🧠 AI Models

The Go version maintains compatibility with all Ollama models. I've tested primarily with the [**qwen2.5-coder**](https://ollama.com/library/qwen2.5-coder) family as they work best for code analysis:

| Model                  | VRAM  | Speed | Quality    |
|------------------------|-------|-------|------------|
| `qwen2.5-coder:1.5b`   | ~1GB  | ⚡⚡⚡⚡  | ⭐⭐       |
| `qwen2.5-coder:3b`     | ~2GB  | ⚡⚡⚡   | ⭐⭐⭐     |
| **`qwen2.5-coder:7b`** | ~5GB  | ⚡⚡⚡   | ⭐⭐⭐⭐   |
| `qwen2.5-coder:14b`    | ~9GB  | ⚡⚡    | ⭐⭐⭐⭐⭐ |
| `qwen2.5-coder:32b`    | ~20GB | ⚡     | ⭐⭐⭐⭐⭐ |

## ⚙️ Configuration

### Command Line Flags

```bash
faff --help
faff --model qwen2.5-coder:3b
faff --host ollama.example.com --port 11434
faff --timeout 5m
```

### Environment Variables

Same as the Bash version for compatibility:

```bash
# Model selection (default: qwen2.5-coder:7b)
export FAFF_MODEL="qwen2.5-coder:14b"

# Ollama connection (defaults to localhost:11434)
export OLLAMA_HOST="your-ollama-server.com"
export OLLAMA_PORT="11434"

# API timeout in seconds (default: 180)
export FAFF_TIMEOUT=300
```

### Configuration Precedence

1. Command line flags (highest priority)
2. Environment variables
3. Built-in defaults (lowest priority)

## 🛠️ Development

### Building

```bash
# Install dependencies
make deps

# Build for current platform
make build

# Build for all platforms
make build-all

# Development build with race detector
make dev
```

### Testing and Quality

```bash
# Run all checks
make check

# Individual commands
make test
make lint
make fmt
```

### Project Structure

```
.
├── main.go              # Main application and CLI
├── go.mod              # Go module definition
├── Makefile            # Build automation
└── README.md           # This file
```

## 🐙 git Integration

Add helpful aliases to your `~/.gitconfig`:

```bash
[alias]
    faff = "!faff"               # Generate commit with faff
    vibe = "!git add . && faff"  # Stage all and commit with faff
```

## 🔄 Migration from Bash Version

The Go version is a drop-in replacement:

- **Same command line interface** - `faff` works exactly the same
- **Same environment variables** - All `FAFF_*` and `OLLAMA_*` variables work identically
- **Same output format** - Generated commit messages are identical
- **Better error messages** - More descriptive failures with suggested fixes
- **Improved performance** - Faster startup, better memory usage, concurrent operations

Simply replace your `faff.sh` with the Go binary and everything continues working.

## 🛟 Troubleshooting

### Common Issues

**❌ "Ollama service is not running"**

```bash
ollama serve
```

**❌ "No changes to commit"**

```bash
git add .
```

**❌ "Model not found"**

The Go version automatically attempts to download missing models with progress indication.

**❌ "Request timed out"**

Increase timeout for large diffs or slow connections:

```bash
faff --timeout 10m
# or
export FAFF_TIMEOUT=600
```

### Debug Information

Use the `--help` flag to see all available options and current configuration:

```bash
faff --help
```

## 🆚 Bash vs Go Comparison

| Feature | Bash Version | Go Version |
|---------|-------------|------------|
| **Dependencies** | `bc`, `curl`, `jq`, `timeout`, `coreutils` | Just the binary |
| **Error Handling** | Best effort with `set -e` | Explicit error propagation |
| **JSON Processing** | External `jq` calls | Native JSON marshaling |
| **HTTP Client** | `curl` with manual timeout | Native HTTP client with context |
| **Concurrency** | Background processes | Native goroutines |
| **Portability** | Unix-like systems only | Cross-platform binary |
| **Memory Usage** | Multiple process spawns | Single process |
| **Startup Time** | ~200ms (tool loading) | ~50ms (direct execution) |
| **Type Safety** | Runtime string manipulation | Compile-time type checking |
| **Testing** | Manual integration tests | Unit tests + integration tests |

## 📦 Binary Releases

Pre-built binaries are available for:

- **Linux**: amd64, arm64
- **macOS**: amd64 (Intel), arm64 (Apple Silicon)
- **Windows**: amd64

Download from the [releases page](https://github.com/wimpysworld/faff/releases) or use the install script above.

## 🤝 Contributing

We welcome contributions! The Go version makes it much easier to:

- **Add features** - Proper module structure and dependency management
- **Fix bugs** - Comprehensive error handling and logging
- **Write tests** - Built-in testing framework with mocking support
- **Improve documentation** - Embedded help and man page generation

Whether you're fixing bugs, adding features, or improving documentation, your help makes `faff` better for everyone.

---

**Drop the faff, dodge the judgment, get back to coding.** 🚀
