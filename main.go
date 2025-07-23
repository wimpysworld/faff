package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/spf13/cobra"
)

const (
	version = "0.2.0"

	systemPrompt = `You will act as a git commit message generator. When receiving a git diff, you will ONLY output the commit message itself, nothing else. No explanations, no questions, no additional comments.

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
- BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.`
)

// Configuration holds all configuration values
type Config struct {
	Model       string
	Host        string
	Port        string
	BaseURL     string
	ChatURL     string
	TagsURL     string
	PullURL     string
	Timeout     time.Duration
	HTTPClient  *http.Client
}

// NewConfig creates a new configuration with defaults and environment overrides
func NewConfig() *Config {
	model := getEnvOrDefault("FAFF_MODEL", "qwen2.5-coder:7b")
	host := getEnvOrDefault("OLLAMA_HOST", "localhost")
	port := getEnvOrDefault("OLLAMA_PORT", "11434")
	timeoutStr := getEnvOrDefault("FAFF_TIMEOUT", "180")

	timeout, err := strconv.Atoi(timeoutStr)
	if err != nil {
		timeout = 180
	}

	baseURL := fmt.Sprintf("http://%s:%s", host, port)

	httpTimeout := time.Duration(timeout) * time.Second

	return &Config{
		Model:      model,
		Host:       host,
		Port:       port,
		BaseURL:    baseURL,
		ChatURL:    baseURL + "/api/chat",
		TagsURL:    baseURL + "/api/tags",
		PullURL:    baseURL + "/api/pull",
		Timeout:    httpTimeout,
		HTTPClient: &http.Client{Timeout: httpTimeout},
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Spinner handles progress indication
type Spinner struct {
	chars   []string
	active  bool
	done    chan bool
	message string
}

func NewSpinner(message string) *Spinner {
	return &Spinner{
		chars:   []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
		message: message,
		done:    make(chan bool),
	}
}

func (s *Spinner) Start() {
	s.active = true
	go func() {
		i := 0
		ticker := time.NewTicker(100 * time.Millisecond)
		defer ticker.Stop()

		for {
			select {
			case <-s.done:
				return
			case <-ticker.C:
				if !s.active {
					return
				}
				fmt.Fprintf(os.Stderr, "\r%s %s", s.chars[i], s.message)
				i = (i + 1) % len(s.chars)
			}
		}
	}()
}

func (s *Spinner) Stop() {
	if s.active {
		s.active = false
		close(s.done)
		// Clear the spinner line
		fmt.Fprintf(os.Stderr, "\r%50s\r", "")
	}
}

// CommitMessage represents the structure expected from Ollama
type CommitMessage struct {
	Type        string `json:"type"`
	Description string `json:"description"`
	Body        string `json:"body,omitempty"`
}

// OllamaMessage represents a message in the Ollama chat format
type OllamaMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// OllamaChatRequest represents the chat request to Ollama
type OllamaChatRequest struct {
	Model    string          `json:"model"`
	Messages []OllamaMessage `json:"messages"`
	Stream   bool            `json:"stream"`
	Format   json.RawMessage `json:"format"`
	Options  map[string]interface{} `json:"options"`
}

// OllamaChatResponse represents the response from Ollama
type OllamaChatResponse struct {
	Message OllamaMessage `json:"message"`
	Error   string        `json:"error,omitempty"`
}

// OllamaModel represents a model in the tags response
type OllamaModel struct {
	Name string `json:"name"`
}

// OllamaTagsResponse represents the response from /api/tags
type OllamaTagsResponse struct {
	Models []OllamaModel `json:"models"`
}

// OllamaPullRequest represents a pull request
type OllamaPullRequest struct {
	Name   string `json:"name"`
	Stream bool   `json:"stream"`
}

// OllamaPullResponse represents a pull response line
type OllamaPullResponse struct {
	Status    string `json:"status"`
	Error     string `json:"error,omitempty"`
	Completed int64  `json:"completed,omitempty"`
	Total     int64  `json:"total,omitempty"`
}

// Faff is the main application struct
type Faff struct {
	config *Config
}

func NewFaff(config *Config) *Faff {
	return &Faff{config: config}
}

// checkDependencies verifies required tools are available
func (f *Faff) checkDependencies() error {
	// Check if we're in a git repository
	cmd := exec.Command("git", "rev-parse", "--is-inside-work-tree")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("this command must be run inside a Git repository")
	}

	// Check for required commands
	requiredCommands := []string{"git"}
	for _, cmd := range requiredCommands {
		if _, err := exec.LookPath(cmd); err != nil {
			return fmt.Errorf("required command '%s' not found in PATH", cmd)
		}
	}

	return nil
}

// getGitDiff gets the staged git diff
func (f *Faff) getGitDiff() (string, error) {
	cmd := exec.Command("git", "--no-pager", "diff", "--staged", "--no-color", "--function-context")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get git diff: %w", err)
	}

	diff := strings.ReplaceAll(string(output), "\r", "")
	if strings.TrimSpace(diff) == "" {
		return "", fmt.Errorf("no changes to commit")
	}

	return diff, nil
}

// checkOllamaService verifies Ollama is running
func (f *Faff) checkOllamaService() error {
	resp, err := f.config.HTTPClient.Get(f.config.BaseURL + "/api/version")
	if err != nil {
		return fmt.Errorf("Ollama service is not running at %s:%s\nPlease start Ollama and try again", f.config.Host, f.config.Port)
	}
	resp.Body.Close()

	fmt.Println("Ollama service is running.")
	return nil
}

// modelExists checks if a model exists locally
func (f *Faff) modelExists(model string) (bool, error) {
	resp, err := f.config.HTTPClient.Get(f.config.TagsURL)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	var tagsResp OllamaTagsResponse
	if err := json.NewDecoder(resp.Body).Decode(&tagsResp); err != nil {
		return false, err
	}

	for _, m := range tagsResp.Models {
		if m.Name == model {
			return true, nil
		}
	}

	return false, nil
}

// formatSize formats bytes into human-readable format
func formatSize(bytes int64) string {
	if bytes >= 1073741824 {
		return fmt.Sprintf("%.1fGB", float64(bytes)/1073741824)
	}
	return fmt.Sprintf("%.0fMB", float64(bytes)/1048576)
}

// pullModel downloads a model from Ollama
func (f *Faff) pullModel(model string) error {
	fmt.Fprintf(os.Stderr, "Model '%s' not found. Attempting to pull it automatically...\n", model)
	fmt.Fprintf(os.Stderr, "Downloading model '%s'. This may take several minutes...\n", model)

	pullReq := OllamaPullRequest{
		Name:   model,
		Stream: true,
	}

	reqBody, err := json.Marshal(pullReq)
	if err != nil {
		return err
	}

	resp, err := f.config.HTTPClient.Post(f.config.PullURL, "application/json", bytes.NewBuffer(reqBody))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	spinnerIndex := 0

	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		var pullResp OllamaPullResponse
		if err := json.Unmarshal(scanner.Bytes(), &pullResp); err != nil {
			continue
		}

		if pullResp.Error != "" {
			fmt.Fprintf(os.Stderr, "\rFailed to pull model '%s': %s\n", model, pullResp.Error)
			return fmt.Errorf("model pull failed: %s", pullResp.Error)
		}

		if pullResp.Completed > 0 && pullResp.Total > 0 {
			percent := int(100 * pullResp.Completed / pullResp.Total)
			completedSize := formatSize(pullResp.Completed)
			totalSize := formatSize(pullResp.Total)

			spinChar := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}[spinnerIndex%10]
			spinnerIndex++

			fmt.Fprintf(os.Stderr, "\r%s Downloading: %d%% (%s/%s)", spinChar, percent, completedSize, totalSize)
		} else if pullResp.Status != "" {
			spinChar := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}[spinnerIndex%10]
			spinnerIndex++
			fmt.Fprintf(os.Stderr, "\r%s %s...", spinChar, pullResp.Status)
		}
	}

	fmt.Fprintf(os.Stderr, "\rModel '%s' downloaded successfully!\n", model)

	// Give Ollama time to index the model
	time.Sleep(2 * time.Second)

	return nil
}

// checkModel verifies model exists or downloads it
func (f *Faff) checkModel() error {
	exists, err := f.modelExists(f.config.Model)
	if err != nil {
		return fmt.Errorf("failed to check model: %w", err)
	}

	if !exists {
		if err := f.pullModel(f.config.Model); err != nil {
			return fmt.Errorf("failed to download model '%s': %w", f.config.Model, err)
		}

		// Verify the model was downloaded
		exists, err = f.modelExists(f.config.Model)
		if err != nil || !exists {
			return fmt.Errorf("model '%s' not available after download", f.config.Model)
		}
	}

	fmt.Printf("Model '%s' is available.\n", f.config.Model)
	return nil
}

// generateCommitMessage calls Ollama to generate a commit message
func (f *Faff) generateCommitMessage(diff string) (string, error) {
	// Create the format specification for structured output
	formatSpec := map[string]interface{}{
		"type": "object",
		"properties": map[string]interface{}{
			"type": map[string]interface{}{
				"type": "string",
				"enum": []string{"feat", "fix", "build", "chore", "ci", "docs", "i18n", "perf", "refactor", "revert", "style", "test"},
			},
			"description": map[string]interface{}{
				"type": "string",
			},
			"body": map[string]interface{}{
				"type": "string",
			},
		},
		"required": []string{"type", "description"},
		"optional": []string{"body"},
	}

	formatJSON, err := json.Marshal(formatSpec)
	if err != nil {
		return "", err
	}

	chatReq := OllamaChatRequest{
		Model: f.config.Model,
		Messages: []OllamaMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: fmt.Sprintf("Here is the diff:\n\n%s", diff)},
		},
		Stream: false,
		Format: formatJSON,
		Options: map[string]interface{}{
			"temperature": 0.3,
		},
	}

	reqBody, err := json.Marshal(chatReq)
	if err != nil {
		return "", err
	}

	ctx, cancel := context.WithTimeout(context.Background(), f.config.Timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "POST", f.config.ChatURL, bytes.NewBuffer(reqBody))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	// Start spinner after request is set up
	spinner := NewSpinner("Generating commit message...")
	spinner.Start()

	resp, err := f.config.HTTPClient.Do(req)
	spinner.Stop() // Stop spinner immediately after request completes

	if err != nil {
		fmt.Fprintf(os.Stderr, "DEBUG: HTTP request failed: %v\n", err)
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("request timed out after %v", f.config.Timeout)
		}
		return "", fmt.Errorf("Ollama API call failed: %w", err)
	}
	defer resp.Body.Close()

	// Debug output
	fmt.Fprintf(os.Stderr, "DEBUG: HTTP request completed, status: %d\n", resp.StatusCode)

	// Debug: Check response status
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("Ollama API returned status %d", resp.StatusCode)
	}

	fmt.Fprintf(os.Stderr, "DEBUG: About to decode JSON response\n")
	var chatResp OllamaChatResponse
	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return "", fmt.Errorf("failed to decode Ollama response: %w", err)
	}
	fmt.Fprintf(os.Stderr, "DEBUG: JSON decoded successfully\n")

	if chatResp.Error != "" {
		return "", fmt.Errorf("Ollama API returned an error: %s", chatResp.Error)
	}

	if chatResp.Message.Content == "" {
		return "", fmt.Errorf("failed to extract message content from Ollama response")
	}

	// Parse the JSON response
	var commitMsg CommitMessage
	if err := json.Unmarshal([]byte(chatResp.Message.Content), &commitMsg); err != nil {
		// Fallback: return the raw content if JSON parsing fails
		return chatResp.Message.Content, nil
	}

	if commitMsg.Type == "" || commitMsg.Description == "" {
		// Fallback: return the raw content if essential fields are missing
		return chatResp.Message.Content, nil
	}

	// Construct the final commit message
	finalMessage := fmt.Sprintf("%s: %s", commitMsg.Type, commitMsg.Description)
	if commitMsg.Body != "" {
		finalMessage += fmt.Sprintf("\n\n%s", commitMsg.Body)
	}

	return finalMessage, nil
}

// confirmCommit handles user interaction for commit confirmation
func (f *Faff) confirmCommit(message string) error {
	fmt.Println("Generated commit message:")
	fmt.Println("-------------------------")
	fmt.Println(message)
	fmt.Println("-------------------------")
	fmt.Println()

	fmt.Print("Do you want to use or edit this commit message? (y/n/e): ")

	var choice string
	fmt.Scanln(&choice)
	choice = strings.ToLower(strings.TrimSpace(choice))

	switch choice {
	case "y", "yes":
		cmd := exec.Command("git", "commit", "-m", message)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("git commit failed: %w", err)
		}
		fmt.Println("Changes committed with the generated message.")

	case "n", "no":
		fmt.Println("Generated commit message only (not committed):")
		fmt.Println(message)

	case "e", "edit":
		cmd := exec.Command("git", "commit", "-m", message, "--edit")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("git commit failed: %w", err)
		}
		fmt.Println("Changes committed with the edited message.")

	default:
		return fmt.Errorf("invalid input. Commit aborted")
	}

	return nil
}

// Run executes the main faff logic
func (f *Faff) Run() error {
	if err := f.checkDependencies(); err != nil {
		return err
	}

	diff, err := f.getGitDiff()
	if err != nil {
		return err
	}

	if err := f.checkOllamaService(); err != nil {
		return err
	}

	if err := f.checkModel(); err != nil {
		return err
	}

	fmt.Println("Generating commit message with Ollama...")
	commitMessage, err := f.generateCommitMessage(diff)
	if err != nil {
		return fmt.Errorf("failed to generate commit message: %w", err)
	}

	if commitMessage == "" {
		return fmt.Errorf("generated commit message is empty")
	}

	return f.confirmCommit(commitMessage)
}

func main() {
	config := NewConfig()
	faff := NewFaff(config)

	var rootCmd = &cobra.Command{
		Use:     "faff",
		Version: version,
		Short:   "Drop the faff, dodge the judgment, get back to coding.",
		Long: `faff generates Git commit messages using local LLMs via Ollama.

Another bloody AI commit generator, but this one stays local 🦙

Stage your changes with 'git add' then run 'faff' to generate
a Conventional Commits compliant message from your diff.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return faff.Run()
		},
	}

	// Add flags for configuration overrides
	rootCmd.Flags().StringVar(&config.Model, "model", config.Model, "Ollama model to use")
	rootCmd.Flags().StringVar(&config.Host, "host", config.Host, "Ollama host")
	rootCmd.Flags().StringVar(&config.Port, "port", config.Port, "Ollama port")
	rootCmd.Flags().DurationVar(&config.Timeout, "timeout", config.Timeout, "API timeout duration")

	// Handle interruption gracefully
	defer func() {
		if r := recover(); r != nil {
			if r == syscall.SIGINT {
				fmt.Fprintf(os.Stderr, "\nInterrupted\n")
				os.Exit(130)
			}
			panic(r)
		}
	}()

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
