#!/usr/bin/env bash

# Drop the faff from your Git commits!
#
# This script automatically generates conventional commit messages
# from your git diffs using an Ollama LLM.

FAFF_MODEL=${FAFF_MODEL:-"qwen2.5-coder:7b"}
OLLAMA_HOST=${OLLAMA_HOST:-"localhost"}
OLLAMA_PORT=${OLLAMA_PORT:-"11434"}
OLLAMA_BASE_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
OLLAMA_API_CHAT="${OLLAMA_BASE_URL}/api/chat"
OLLAMA_API_BASE="${OLLAMA_BASE_URL}/api"
# Timeout in seconds for Ollama API calls
FAFF_TIMEOUT=${FAFF_TIMEOUT:-180} 
# Spinner characters for progress indication
SPINNER_CHARS=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )

# Output error message to stderr
function error_exit() {
    echo "Error: $1" >&2
    exit "${2:-1}"
}

# Clean up temporary files
function cleanup_temp_files() {
    rm -f "$@"
}

# Check dependencies
function check_dependencies() {
    command -v bc &>/dev/null || error_exit "bc is not installed. Please install it and try again."
    command -v curl &>/dev/null || error_exit "curl is not installed. Please install it and try again."
    command -v jq &>/dev/null || error_exit "jq is not installed. Please install it and try again."
    git rev-parse --is-inside-work-tree &>/dev/null || error_exit "This script must be run inside a Git repository."
}

# Function to show spinner during API calls
function show_spinner() {
    local pid=$1
    local message="$2"
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        local spin_char=${SPINNER_CHARS[$i]}
        printf "\r%s %s" "$spin_char" "$message" >&2
        i=$(((i + 1) % ${#SPINNER_CHARS[@]}))
        sleep 0.1
    done
    printf "\r%*s\r" "50" "" >&2  # Clear the spinner line completely
}

# Get the staged git diff
function get_git_diff() {
    git --no-pager diff --staged --no-color --function-context | tr -d '\r'
}

# Function to generate the commit message using Ollama
function generate_commit_message() {
    local diff="$1"
    
    # Create a temporary file for the system prompt
    local SYSTEM_PROMPT_FILE
    SYSTEM_PROMPT_FILE=$(mktemp)
    cat > "$SYSTEM_PROMPT_FILE" << 'EOF'
You will act as a git commit message generator. When receiving a git diff, you will ONLY output the commit message itself, nothing else. No explanations, no questions, no additional comments.

Commits must follow the Conventional Commits 1.0.0 specification and be further refined using the rules outlined below.

The commit message must include the following fields: "type", "description", "body".
The commit message must be in the format:
<type>([optional scope]): <description>

[body]

[optional footer(s)]

- "type": Choose one of the following:
  - feat: MUST be used when commits that introduce new features or functionalities to the project (this correlates with MINOR in Semantic Versioning)
  - fix: MUST be used when commits address bug fixes or resolve issues in the project (this correlates with PATCH in Semantic Versioning)
  - types other than feat: and fix: can be used in your commit messages:
    - build: Used when a commit affects the build system or external dependencies. It includes changes to build scripts, build configurations, or build tools used in the project
    - chore: Typically used for routine or miscellaneous tasks related to the project, such as code reformatting, updating dependencies, or making general project maintenance
    - ci: CI stands for continuous integration. This type is used for changes to the project's continuous integration or deployment configurations, scripts, or infrastructure
    - docs: Documentation plays a vital role in software projects. The docs type is used for commits that update or add documentation, including readme files, API documentation, user guides or code comments that act as documentation
    - i18n: This type is used for commits that involve changes related to internationalization or localization. It includes changes to localization files, translations, or internationalization-related configurations.
    - perf: Short for performance, this type is used when a commit improves the performance of the code or optimizes certain functionalities
    - refactor: Commits typed as refactor involve making changes to the codebase that neither fix a bug nor add a new feature. Refactoring aims to improve code structure, organization, or efficiency without changing external behavior
    - revert: Commits typed as revert are used to undo previous commits. They are typically used to reverse changes made in previous commits
    - style: The style type is used for commits that focus on code style changes, such as formatting, indentation, or whitespace modifications. These commits do not affect the functionality of the code but improve its readability and maintainability
    - test: Used for changes that add or modify test cases, test frameworks, or other related testing infrastructure.
- "description": A very brief summary line (max 72 characters). Do not end with a period. Use imperative mood (e.g., 'add feature' not 'added feature').
- "body": A more detailed explanation of the changes, focusing on what problem this commit solves and why this change was necessary. Small changes can be a concise, specific sentence. Larger changes should be a bulleted list of concise, specific changes. Include optional footers like BREAKING CHANGE here.

Guidelines for writing the commit message:
- The <description> must be in English
- The [optional scope] must be in English
- The <description> must be imperative mood
- The <description> must avoid capitalization
- The <description> will not have a period at the end
- The <description> will have a maximum of 72 characters including any spaces or special characters
- The <description> must avoid using the <type> as the first word
- Follow the <description> with a blank line, then the [body].
- The [body] must be in English
- The [body] should provide a more detailed explanation. Small changes as one sentence, larger changes as a bulleted list.
- The [body] should explain what and why
- The [body] will be objective
- Bullet points in the [body] start with "-"
- The [optional footer(s)] can be used for things like referencing issues or indicating breaking changes.

Specification for Conventional Commits:
- Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space.
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
      --arg model "$FAFF_MODEL" \
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
            content: ("Here is the diff:\n\n" + $diff_content)
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
    cleanup_temp_files "$SYSTEM_PROMPT_FILE" "$PAYLOAD_FILE"

    local response
    local curl_exit_code=0

    # Start the API call in background and show spinner
    (
        timeout "$FAFF_TIMEOUT" curl -s -X POST "$OLLAMA_API_CHAT" \
          -H "Content-Type: application/json" \
          --max-time "$FAFF_TIMEOUT" \
          -d "$payload" > /tmp/ollama_response_$$
        echo "$?" > /tmp/curl_exit_code_$$
    ) &
    
    local api_pid=$!
    show_spinner $api_pid "Generating commit message..."
    wait $api_pid
    
    # Clear the spinner line completely
    printf "\r%*s\r" "50" "" >&2
    
    # Read results
    curl_exit_code=$(cat /tmp/curl_exit_code_$$ 2>/dev/null || echo "1")
    response=$(cat /tmp/ollama_response_$$ 2>/dev/null || echo "")
    
    # Clean up temp files
    cleanup_temp_files /tmp/curl_exit_code_$$ /tmp/ollama_response_$$

    if [ $curl_exit_code -ne 0 ]; then
        echo "Error: Ollama API call failed with exit code $curl_exit_code." >&2
        if [ $curl_exit_code -eq 124 ]; then
            echo "Error: Request timed out after $FAFF_TIMEOUT seconds." >&2
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
        final_commit_message="${final_commit_message}\\n\\n${body}"
    fi
    
    echo -e "$final_commit_message"
}

function check_model() {
  local model="$1"
  local error
  local completed
  local total
  local percent
  local spin_char
  local i=0

  # Check if model exists
  if ! curl -s "${OLLAMA_API_BASE}/tags" | jq -e --arg M "$model" '.models[] | select(.name == $M)' >/dev/null; then
    echo "Model '$model' not found. Attempting to pull it automatically..." >&2
    echo "Downloading model '$model'. This may take several minutes..." >&2
    
    local pull_payload
    pull_payload=$(printf '{"name": "%s", "stream": true}' "$model")

    # Use stream mode to show progress; curl command on a single line
    curl -s -X POST "${OLLAMA_API_BASE}/pull" -H "Content-Type: application/json" -d "$pull_payload" | 
    while read -r line; do
      if echo "$line" | grep -q "error"; then
        error=$(echo "$line" | jq -r '.error')
        echo -e "\\rFailed to pull model '$model': $error                    " >&2
        echo "Try using one of these available models instead:" >&2
        curl -s "${OLLAMA_API_BASE}/tags" | jq -r '.models[].name' | head -5 | sed 's/^/   - /' >&2
        return 1
      elif echo "$line" | grep -q "status"; then
        # Check if this line contains progress information
        if echo "$line" | jq -e '.completed' >/dev/null 2>&1 && echo "$line" | jq -e '.total' >/dev/null 2>&1; then
          completed=$(echo "$line" | jq -r '.completed // 0')
          total=$(echo "$line" | jq -r '.total // 0')
          percent=0
          
          if [[ $total != "0" && $total != "" && $total != "null" ]]; then
            percent=$(echo "scale=0; 100*$completed/$total" | bc 2>/dev/null || echo "0")
          fi
          
          # Format sizes in human-readable format (MB/GB only)
          local completed_human total_human completed_unit total_unit
          if [[ $total -ge 1073741824 ]]; then
            # Total is GB, show total in GB
            total_human=$(echo "scale=1; $total/1073741824" | bc 2>/dev/null || echo "0")
            total_unit="GB"
            # Show completed in MB if less than 1GB, otherwise in GB
            if [[ $completed -ge 1073741824 ]]; then
              completed_human=$(echo "scale=1; $completed/1073741824" | bc 2>/dev/null || echo "0")
              completed_unit="GB"
            else
              completed_human=$(echo "scale=0; $completed/1048576" | bc 2>/dev/null || echo "0")
              completed_unit="MB"
            fi
          else
            # Total is less than GB, show both in MB
            completed_human=$(echo "scale=0; $completed/1048576" | bc 2>/dev/null || echo "0")
            total_human=$(echo "scale=0; $total/1048576" | bc 2>/dev/null || echo "0")
            completed_unit="MB"
            total_unit="MB"
          fi
          
          spin_char=${SPINNER_CHARS[$i]}
          i=$(((i + 1) % ${#SPINNER_CHARS[@]}))
          
          echo -ne "\\r$spin_char Downloading: $percent% ($completed_human$completed_unit/$total_human$total_unit)                    " >&2
        else
          # Show spinner even without detailed progress
          spin_char=${SPINNER_CHARS[$i]}
          i=$(((i + 1) % ${#SPINNER_CHARS[@]}))
          
          status=$(echo "$line" | jq -r '.status // "downloading"')
          echo -ne "\\r$spin_char $status...                                        " >&2
        fi
      fi
    done
    
    # Give Ollama a moment to index the new model
    sleep 2 
    # Re-check if model was downloaded successfully
    if curl -s "${OLLAMA_API_BASE}/tags" | jq -e --arg M "$model" '.models[] | select(.name == $M)' >/dev/null; then
      echo -e "\\rModel '$model' downloaded successfully!                                   " >&2
      return 0
    else
      echo -e "\\rSomething went wrong during download. Model '$model' not available.       " >&2
      return 1
    fi
  fi
  return 0
}

# Function to check Ollama service and model
function check_ollama_service_and_model() {
    # Check if Ollama service is running
    if ! curl -s -o /dev/null "${OLLAMA_API_BASE}/version"; then
        error_exit "Ollama service is not running at ${OLLAMA_HOST}:${OLLAMA_PORT}.\nPlease start Ollama and try again."
    fi
    echo "Ollama service is running."

    # Check if model exists using the new function
    if ! check_model "$FAFF_MODEL"; then
        exit 1
    fi
    echo "Model '$FAFF_MODEL' is available."
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

    case "${choice,,}" in
        y|yes)
            git commit -m "$generated_message"
            echo "Changes committed with the generated message."
            ;;
        n|no)
            echo "Generated commit message only (not committed):"
            echo "$generated_message"
            ;;
        *)
            echo "Invalid input. Commit aborted."
            ;;
    esac
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