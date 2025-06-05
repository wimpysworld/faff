#!/usr/bin/env bash

# Drop the faff from your Git commits!
#
# This script automatically generates conventional commit messages
# from your git diffs using an Ollama LLM.

OLLAMA_MODEL=${OLLAMA_MODEL:-"qwen2.5-coder:7b"}
OLLAMA_HOST=${OLLAMA_HOST:-"localhost"}
OLLAMA_PORT=${OLLAMA_PORT:-"11434"}
OLLAMA_BASE_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
OLLAMA_API_CHAT="${OLLAMA_BASE_URL}/api/chat"
OLLAMA_API_BASE="${OLLAMA_BASE_URL}/api"
# Timeout in seconds for Ollama API calls
TIMEOUT=180 

# Function to check dependencies
function check_dependencies() {
    if ! command -v ollama &>/dev/null; then
        echo "Error: Ollama CLI is not installed. Please install it and try again."
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        echo "Error: curl is not installed. Please install it and try again."
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq is not installed. Please install it and try again."
        exit 1
    fi

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Error: This script must be run inside a Git repository."
        exit 1
    fi
}

# Get the staged git diff
function get_git_diff() {
    git --no-pager diff --staged --no-color --function-context
}

# Function to generate the commit message using Ollama
function generate_commit_message() {
    local diff="$1"
    
    # Create a temporary file for the system prompt
    local SYSTEM_PROMPT_FILE
    SYSTEM_PROMPT_FILE=$(mktemp)
    cat > "$SYSTEM_PROMPT_FILE" << 'EOF'
Based on the git diff, generate a git commit message adhering to the Conventional Commits specification.

The commit message must include the following fields: "type", "description", "body".
The commit message must be in the format:
<type>([optional scope]): <description>

[body]

[optional footer(s)]

- "type": Choose one of the following:
  - fix: a commit of the type fix patches a bug in the codebase (this correlates with PATCH in Semantic Versioning).
  - feat: a commit of the type feat introduces a new feature to the codebase (this correlates with MINOR in Semantic Versioning).
  - types other than fix: and feat: are allowed, for example:
    - build: Changes that affect the build system or external dependencies
    - chore: Other changes that don't modify src or test files
    - ci: Changes to CI configuration files, scripts
    - docs: Documentation only changes
    - perf: A code change that improves performance
    - refactor: A code change that neither fixes a bug nor adds a feature
    - revert: Reverts a previous commit
    - style: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
    - test: Adding missing tests or correcting existing tests
- "description": A very brief summary line (max 72 characters). Do not end with a period. Use imperative mood (e.g., 'add feature' not 'added feature').
- "body": A more detailed explanation of the changes, focusing on what problem this commit solves and why this change was necessary. It can be a bulleted list of concise, specific changes. Include optional footers like BREAKING CHANGE here.

Guidelines for writing the commit message:
- The <description> should be a very brief summary line (must be 72 characters or less).
- The first letter of <description> must be lower case. 
- The <description> must be lowercase. 
- The <description> must avoid using the <type> as the first word.
- Follow the <description> with a blank line, then the [optional body].
- The [body] should provide a more detailed explanation.
- The [optional footer(s)] can be used for things like referencing issues or indicating breaking changes.

Specification for Conventional Commits:
- Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space.
- The type feat MUST be used when a commit adds a new feature to your application or library.
- The type fix MUST be used when a commit represents a bug fix for your application.
- A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
- A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., fix: array parsing issue when multiple spaces were contained in string.
- A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
- A commit body is free-form and MAY consist of any number of newline separated paragraphs.
- One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by either a :<space> or <space># separator, followed by a string value (this is inspired by the git trailer convention).
- A footer's token MUST use - in place of whitespace characters, e.g., Acked-by (this helps differentiate the footer section from a multi-paragraph body). An exception is made for BREAKING CHANGE, which MAY also be used as a token.
- A footer's value MAY contain spaces and newlines, and parsing MUST terminate when the next valid footer token/separator pair is observed.
- Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer.
- If included as a footer, a breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon, space, and description, e.g., BREAKING CHANGE: environment variables now take precedence over config files.
- If included in the type/scope prefix, breaking changes MUST be indicated by a ! immediately before the :. If ! is used, BREAKING CHANGE: MAY be omitted from the footer section, and the commit description SHALL be used to describe the breaking change.
- Types other than feat and fix MAY be used in your commit messages, e.g., docs: update ref docs.
- The units of information that make up Conventional Commits MUST NOT be treated as case sensitive by implementors, with the exception of BREAKING CHANGE which MUST be uppercase.
- BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.
EOF

    # Properly escape the git diff for JSON using jq
    local GIT_DIFF
    GIT_DIFF=$(echo "$diff" | jq -Rs .)

    # Create a temporary file for storing the payload
    local PAYLOAD_FILE
    PAYLOAD_FILE=$(mktemp)

    jq -n \
      --arg model "$OLLAMA_MODEL" \
      --rawfile system "$SYSTEM_PROMPT_FILE" \
      --argjson diff_content "$GIT_DIFF" \
      '{
        model: $model,
        messages: [
          {
            role: "system",
            content: $system
          },
          {
            role: "user",
            content: $diff_content
          }
        ],
        stream: false,
        format: {
          type: "object",
          properties: {
            type: {
              type: "string",
              enum: ["feat", "fix", "build", "chore", "ci", "docs", "perf", "refactor", "revert", "style", "test" ]
            },
            description: {
              type: "string"
            },
            body: {
              type: "string"
            }
          },
          required: ["type", "description"],
          optional: ["body"]
        },
        options: {
          "temperature": 0.3
        }
      }' > "$PAYLOAD_FILE"

    local payload
    payload=$(<"$PAYLOAD_FILE")

    # Clean up temporary files
    rm -f "$SYSTEM_PROMPT_FILE" "$PAYLOAD_FILE"

    local response
    local curl_exit_code=0

    response=$(timeout "$TIMEOUT" curl -s -X POST "$OLLAMA_API_CHAT" \
      -H "Content-Type: application/json" \
      --max-time "$TIMEOUT" \
      -d "$payload")
    curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        echo "Error: Ollama API call failed with exit code $curl_exit_code." >&2
        if [ $curl_exit_code -eq 124 ]; then
            echo "Error: Request timed out after $TIMEOUT seconds." >&2
        fi
        return 1
    fi

    # Check for error in response
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.error')
        echo "Error: Ollama API returned an error: $error_msg" >&2
        return 1
    fi
    
    local message_content
    message_content=$(echo "$response" | jq -r '.message.content')

    if [ -z "$message_content" ] || [ "$message_content" == "null" ]; then
        echo "Error: Failed to extract message content from Ollama response." >&2
        echo "Full response: $response" >&2
        return 1
    fi
    
    # Attempt to parse the message content as JSON
    local type description body
    if ! type=$(echo "$message_content" | jq -r '.type // empty') || \
       ! description=$(echo "$message_content" | jq -r '.description // empty') || \
       ! body=$(echo "$message_content" | jq -r '.body // empty'); then
        echo "Error: Could not parse type, description, or body from Ollama's message content." >&2
        echo "Message content: $message_content" >&2
        # Fallback: use the whole message content as the commit message if it's not JSON
        # This might happen if the model doesn't strictly follow the JSON format instruction
        echo "$message_content"
        return 0
    fi


    if [ -z "$type" ] || [ -z "$description" ]; then
        echo "Error: Ollama response missing 'type' or 'description'." >&2
        echo "Parsed content: Type='$type', Description='$description'" >&2
        echo "Message content from API: $message_content" >&2
        # Fallback to using the raw message content if essential parts are missing
        echo "$message_content"
        return 0
    fi

    local final_commit_message="${type}: ${description}"
    if [ -n "$body" ] && [ "$body" != "null" ]; then
        final_commit_message="${final_commit_message}\n\n${body}"
    fi
    
    echo -e "$final_commit_message"
}

# Function to check Ollama service and model
function check_ollama_service_and_model() {
    # Check if Ollama service is running
    if ! curl -s -o /dev/null "${OLLAMA_API_BASE}/version"; then
        echo "Error: Ollama service is not running at ${OLLAMA_HOST}:${OLLAMA_PORT}." >&2
        echo "Please start Ollama and try again." >&2
        exit 1
    fi
    echo "Ollama service is running."

    # Check if model exists
    if ! curl -s "${OLLAMA_API_BASE}/tags" | jq -e ".models[] | select(.name==\"$OLLAMA_MODEL\")" >/dev/null; then
        echo "Model '$OLLAMA_MODEL' not found locally. Attempting to pull it via Ollama CLI..." >&2
        if ollama pull "$OLLAMA_MODEL"; then
            echo "Model '$OLLAMA_MODEL' pulled successfully."
        else
            echo "Error: Failed to pull model '$OLLAMA_MODEL'. Please ensure the model name is correct and Ollama can access it." >&2
            exit 1
        fi
    else
        echo "Model '$OLLAMA_MODEL' is available."
    fi
}

# Function to handle user interaction
function confirm_commit() {
    local generated_message="$1"

    echo "Generated commit message:"
    echo "-------------------------"
    echo "$generated_message"
    echo "-------------------------"
    echo ""

    read -p "Do you want to use this commit message? (y/n): " choice

    if [[ $choice == "y" || $choice == "Y" ]]; then
        git commit -m "$generated_message"
        echo "Changes committed with the generated message."
    elif [[ $choice == "n" || $choice == "N" ]]; then
        echo "Generated commit message only (not committed):"
        echo "$generated_message"
    else
        echo "Invalid input. Commit aborted."
    fi
}

# Main script logic
function main() {
    check_dependencies
    check_ollama_service_and_model

    local diff
    diff=$(get_git_diff)

    if [ -z "$diff" ]; then
        echo "No changes to commit"
        exit 1
    fi

    local commit_message
    echo "Generating commit message with Ollama..."
    commit_message=$(generate_commit_message "$diff")

    if [ -z "$commit_message" ]; then
        echo "Error: Failed to generate commit message."
        exit 1
    fi

    confirm_commit "$commit_message"
}

main