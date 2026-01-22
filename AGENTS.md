# AGENTS.md

CLI tool that generates Conventional Commits messages from git diffs using local LLMs via Ollama. Single-file bash script, privacy-first (no cloud APIs).

## Tech stack

- Bash 4.0+ (single script: `faff.sh`)
- Ollama API for local LLM inference
- Dependencies: `curl`, `jq`, `bc`, coreutils (`timeout`)

## Run commands

```bash
# Run directly (requires staged git changes and Ollama running)
./faff.sh

# With custom model
FAFF_MODEL="qwen2.5-coder:3b" ./faff.sh

# Validate script syntax
bash -n faff.sh
```

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FAFF_MODEL` | `qwen2.5-coder:7b` | Ollama model to use |
| `FAFF_TIMEOUT` | `180` | API timeout in seconds |
| `OLLAMA_HOST` | `localhost` | Ollama server hostname |
| `OLLAMA_PORT` | `11434` | Ollama server port |
| `OLLAMA_PROTOCOL` | `http` | Protocol for Ollama connection (http/https) |
| `OLLAMA_TOKEN` | (empty) | Optional API token for authenticated Ollama servers |

## Code style

- Bash script with `#!/usr/bin/env bash`
- Use `function name()` syntax for function declarations
- Use `local` for function-scoped variables
- Use `readonly` for constants
- Error messages to stderr via `error_exit` function
- Spinner feedback for long-running operations

## Commit guidelines

Follow Conventional Commits 1.0.0 specification:

```
<type>: <description>

[body]
```

**Types:** `feat`, `fix`, `build`, `chore`, `ci`, `docs`, `i18n`, `perf`, `refactor`, `revert`, `style`, `test`

- Description: imperative mood, max 72 chars, no period, no capitalisation
- Body: explains what and why, uses `-` for bullet points

## Architecture

Single script (`faff.sh`) with these key functions:

- `main()` - Entry point, orchestrates workflow
- `check_dependencies()` - Validates bash version and required tools
- `get_git_diff()` - Retrieves staged changes
- `get_allowed_scopes()` - Detects commitlint config and extracts allowed scopes
- `generate_commit_message()` - Calls Ollama API with structured JSON output
- `check_model()` - Auto-downloads missing models
- `confirm_commit()` - Interactive prompt (y/n/e for yes/no/edit)

The script embeds a detailed system prompt for Conventional Commits compliance, using Ollama's structured output format to ensure consistent JSON responses.

## Integrations

**Commitlint:** Auto-detects `.commitlintrc.json` or `commitlint.config.json` and extracts `scope-enum` to constrain LLM scope selection. Passive feature - no impact if no config exists.

## Constraints

- Must run inside a git repository with staged changes
- Requires Ollama service running and accessible
- Bash 4.0+ required (uses associative array syntax)
- No external config files - all configuration via environment variables
