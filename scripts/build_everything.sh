#!/usr/bin/env bash

set -euo pipefail


################################################################
#                                                              CONFIGURATION
################################################################


# This number controls the next build artifact number.
# Example:
# file_number=1 creates tfplan-1, security-findings-1.txt, ai-security-doc-1.md
file_number=3

# Find the folder where this script lives.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Store the full path to this script.
# Used later to update file_number automatically.
SCRIPT_FILE="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"

# Move one folder up from scripts/ to the Terraform root.
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Store all plan/security/AI files in scripts/build_plan.
PLAN_DIR="${SCRIPT_DIR}/build_plan"

# Ollama model used for local AI documentation.
AI_MODEL="gemma4:12b"

# Ollama local API endpoint.
OLLAMA_URL="http://localhost:11434/api/generate"

# Output files for this run.
SECURITY_FILE="${PLAN_DIR}/security-findings-${file_number}.txt"
CLEAN_SECURITY_FILE="${PLAN_DIR}/security-findings-clean-${file_number}.txt"
AI_DOC_FILE="${PLAN_DIR}/ai-security-doc-${file_number}.md"

# Main AI prompt file.
PROMPT_FILE="${SCRIPT_DIR}/prompt.md"

# Temporary combined prompt sent to Ollama.
AI_REQUEST_PROMPT_FILE="${PLAN_DIR}/ai-request-prompt-${file_number}.txt"

################################################################
#                                 Checking Requirements
################################################################

echo "Checking required dependencies..."

missing_deps=()

check_command() {
  local cmd="$1"
  local name="$2"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_deps+=("$name")
  fi
}

check_command terraform "Terraform"
check_command grep "grep"
check_command awk "awk"
check_command ollama "Ollama"
check_command gitleaks "Gitleaks"
check_command tflint "TFLint"
check_command checkov "Checkov"
check_command trivy "Trivy"
check_command docker "Docker"

if [ "${#missing_deps[@]}" -gt 0 ]; then
  echo "Missing required dependencies:"
  for dep in "${missing_deps[@]}"; do
    echo "- $dep"
  done
  exit 0
fi

if [ -z "${AI_MODEL:-}" ]; then
  echo "AI_MODEL is not set"
  exit 0
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Prompt file not found: $PROMPT_FILE"
  exit 0
fi

if ! ollama list | awk 'NR > 1 {print $1}' | grep -Fxq "$AI_MODEL"; then
  echo "Go install $AI_MODEL"
  exit 0
fi

echo "Found $AI_MODEL"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed, but Docker Desktop / Docker daemon is not running"
  echo "Start Docker Desktop, then rerun the script"
  exit 0
fi

echo "Docker daemon is running"

echo "All required dependencies found."
# Continue script here


################################################################
#                                                              TERMINAL COLORS
################################################################


# These colors only affect terminal output.
BLUE="\033[1;34m"
GREEN="\033[1;32m"
PURPLE="\033[1;35m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"


################################################################
#                                                              AI DOCUMENTATION PROMPT
################################################################


# This is the instruction sent to the local AI model.
# The AI uses this prompt plus the clean security findings file.
AI_PROMPT=$(cat "$PROMPT_FILE")

################################################################
#                                                              HELPER FUNCTION: CLEAN FILE OUTPUT
################################################################


# Removes bad terminal characters from files.
# This fixes ESC[K, [6D, [16D, and other control-character garbage.
clean_file() {
  local input_file="$1"
  local output_file="$2"

  perl -CSD -pe '
    s/\x1B(?:[@-Z\\-_]|\[[0-?]*[ -\/]*[@-~])//g;
    s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g;
    s/[ \t]+$//g;
  ' "$input_file" > "$output_file"
}


################################################################
#                                                              START LOCAL AI MODEL
################################################################


# This warms up the Ollama model before the Terraform work starts.
# keep_alive=30m tells Ollama to keep the model loaded for 30 minutes.
# think=false tells the model not to return thinking output.
echo -e "${PURPLE}Starting Ollama model: ${AI_MODEL}${RESET}"

if command -v ollama >/dev/null 2>&1; then
  curl -s "$OLLAMA_URL" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${AI_MODEL}\",\"prompt\":\"\",\"stream\":false,\"keep_alive\":\"30m\",\"think\":false}" >/dev/null \
    || echo -e "${YELLOW}Ollama server not running. AI documentation may fail.${RESET}"
else
  echo -e "${YELLOW}Ollama not installed or not in PATH. AI documentation will be skipped.${RESET}"
fi


################################################################
#                                                              MOVE TO TERRAFORM ROOT DIRECTORY
################################################################


# The script lives in scripts/.
# Terraform files live one level above scripts/.
echo -e "${BLUE}Moving to Terraform root directory...${RESET}"
cd "$ROOT_DIR"

# Create the build_plan folder if it does not already exist.
mkdir -p "$PLAN_DIR"
echo -e "${GREEN}Build plan directory ready: $PLAN_DIR${RESET}"


################################################################
#                                                              TERRAFORM INIT VALIDATE FORMAT
################################################################


# Downloads Terraform providers and prepares the working directory.
echo "Initializing Terraform..."
terraform init

# Checks if the Terraform configuration is valid.
echo "Validating Terraform configuration..."
terraform validate

# Formats all Terraform files recursively.
echo "Formatting Terraform files..."
terraform fmt -recursive


################################################################
#                                                              LOCAL SECURITY SCANNING
################################################################


# This section runs lightweight local checks before creating the plan.
# It writes all raw scan results to SECURITY_FILE.
echo "Running local security checks..."

{
  echo "# Security Findings - Plan ${file_number}"
  echo

  echo "## Terraform Format Check"
  if command -v terraform >/dev/null 2>&1; then
    terraform fmt -check -recursive -diff -no-color || true
  else
    echo "Terraform not installed; skipping."
  fi

  echo
  echo "## Terraform Validate"
  if command -v terraform >/dev/null 2>&1; then
    terraform init -backend=false -input=false -no-color >/dev/null 2>&1 || echo "WARN: terraform init -backend=false failed; validate may fail."
    terraform validate -no-color || true
  else
    echo "Terraform not installed; skipping."
  fi

  echo
  echo "## Secret Scan"
  grep -RInE 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|aws_secret_access_key|BEGIN .*PRIVATE KEY|client_secret|password[[:space:]]*=' \
    --include="*.tf" \
    --include="*.tfvars" \
    --exclude-dir=".terraform" \
    --exclude-dir=".git" \
    --exclude-dir="build_plan" \
    . || echo "PASS: No secret-like values found."

  echo
  echo "## Gitleaks Secret Scan"
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks dir . --no-banner --no-color --redact --verbose || true
  else
    echo "Gitleaks not installed; skipping."
  fi

  echo
  echo "## Public Exposure Scan"
  grep -RInE '0\.0\.0\.0/0|::/0|allUsers|allAuthenticatedUsers' \
    --include="*.tf" \
    --include="*.tfvars" \
    --exclude-dir=".terraform" \
    --exclude-dir=".git" \
    --exclude-dir="build_plan" \
    . || echo "PASS: No obvious public exposure found."

  echo
  echo "## IAM Privilege Scan"
  grep -RInE 'Action.*"\*"|actions.*"\*"|roles/owner|roles/editor|roles/.+Admin' \
    --include="*.tf" \
    --include="*.tfvars" \
    --exclude-dir=".terraform" \
    --exclude-dir=".git" \
    --exclude-dir="build_plan" \
    . || echo "PASS: No obvious wildcard/admin IAM found."

  echo
  echo "## TFLint Terraform Lint Scan"
  if command -v tflint >/dev/null 2>&1; then
    tflint --init || true
    tflint --recursive --format compact || true
  else
    echo "TFLint not installed; skipping."
  fi

  echo
  echo "## Checkov IaC Scan"
  if command -v checkov >/dev/null 2>&1; then
    NO_COLOR=1 checkov -d . \
      --framework terraform \
      --quiet \
      --compact \
      --skip-path .terraform \
      --skip-path .git \
      --skip-path build_plan || true
  else
    echo "Checkov not installed; skipping."
  fi

  echo
  echo "## Trivy IaC Scan"
  if command -v trivy >/dev/null 2>&1; then
    NO_COLOR=1 TERM=dumb trivy config . \
      --severity HIGH,CRITICAL \
      --no-progress \
      --format table \
      --skip-dirs .terraform \
      --skip-dirs .git \
      --skip-dirs build_plan || true
  else
    echo "Trivy not installed; skipping."
  fi

  echo
  echo "## KICS IaC Scan"
  if command -v docker >/dev/null 2>&1; then
    MSYS_NO_PATHCONV=1 docker run --rm \
      -v "$PWD:/src" \
      checkmarx/kics:latest scan \
      -p /src \
      -o /tmp \
      --no-progress || true
  else
    echo "Docker not installed; skipping KICS."
  fi

  echo
  echo "## Terrascan IaC Scan"
  if command -v docker >/dev/null 2>&1; then
    MSYS_NO_PATHCONV=1 docker run --rm \
      -v "$PWD:/src" \
      tenable/terrascan scan \
      -i terraform \
      -d /src || true
  else
    echo "Docker not installed; skipping Terrascan."
  fi

} > "$SECURITY_FILE"

# Create a clean copy for the AI model to read.
clean_file "$SECURITY_FILE" "$CLEAN_SECURITY_FILE"

echo -e "${GREEN}Security findings saved:       $SECURITY_FILE${RESET}"
echo -e "${GREEN}Clean security findings saved: $CLEAN_SECURITY_FILE${RESET}"


################################################################
#                                                              TERRAFORM PLAN GENERATION
################################################################


# Creates a binary Terraform plan.
# This is the file Terraform can apply later.
echo "Creating Terraform plan..."
terraform plan -out="${PLAN_DIR}/tfplan-${file_number}"

# Creates a human-readable text version of the plan.
echo "Saving readable Terraform plan..."
terraform show -no-color "${PLAN_DIR}/tfplan-${file_number}" > "${PLAN_DIR}/tfplan-${file_number}.txt"

# Creates a JSON version of the plan.
# Useful later for automation, AI review, or policy checks.
echo "Saving Terraform plan JSON..."
terraform show -json "${PLAN_DIR}/tfplan-${file_number}" > "${PLAN_DIR}/tfplan-${file_number}.json"


# Enable it if you want but I for this instance want the entire thing to go automatically.
# read -p "Type Apply to build the plan: " confirm

# if [ "$confirm" != "Apply" ]; then
#   echo "Apply cancelled."
  
#   echo -e "${PURPLE}Shutting down Ollama model: ${AI_MODEL}${RESET}"

#   curl -s "$OLLAMA_URL" \
#     -H "Content-Type: application/json" \
#     -d "{\"model\":\"${AI_MODEL}\",\"prompt\":\"\",\"stream\":false,\"keep_alive\":0}" >/dev/null || true

#   exit 0
# fi

echo "Applying plan..."
terraform apply "${PLAN_DIR}/tfplan-${file_number}"


################################################################
#                                                              AI DOCUMENTATION GENERATION
################################################################


# This section sends the clean security findings to the local AI model.
# It generates a polished Markdown security review.
echo -e "${PURPLE}Generating AI security documentation with ${AI_MODEL}...${RESET}"

if command -v ollama >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  {
    cat "$PROMPT_FILE"
    echo
    echo "RAW TERRAFORM SECURITY FINDINGS:"
    echo
    cat "$CLEAN_SECURITY_FILE"
  } > "$AI_REQUEST_PROMPT_FILE"

  jq -n \
    --arg model "$AI_MODEL" \
    --rawfile prompt "$AI_REQUEST_PROMPT_FILE" \
    '{
      model: $model,
      prompt: $prompt,
      stream: false,
      think: false,
      keep_alive: "30m",
      options: {
        temperature: 0.5,
        top_p: 0.9,
        num_ctx: 9999999999
      }
    }' \
  | curl -s "$OLLAMA_URL" \
      -H "Content-Type: application/json" \
      -d @- \
  | jq -r '.response // empty' \
  > "$AI_DOC_FILE.tmp"

  # Remove thinking output if the model still returns it.
  perl -0pi -e 's/Thinking\.\.\..*?\.\.\.done thinking\.//sg' "$AI_DOC_FILE.tmp"

  # Clean final AI Markdown output.
  clean_file "$AI_DOC_FILE.tmp" "$AI_DOC_FILE"
  rm -f "$AI_DOC_FILE.tmp"

  if [ ! -s "$AI_DOC_FILE" ]; then
    echo -e "${RED}AI documentation file is empty. Check Ollama model/API output.${RESET}"
  else
    echo -e "${GREEN}AI documentation saved: $AI_DOC_FILE${RESET}"
  fi
else
  echo -e "${YELLOW}Ollama or jq not available. Skipping AI documentation.${RESET}"
fi


################################################################
#                                                              UPDATE PLAN NUMBER
################################################################


# Increment file_number for the next run.
# This updates the file_number line by searching for file_number= instead of relying on line numbers.
echo "Setting new plan number..."
next_file_number=$((file_number + 1))

echo "Changing plan number..."
sed -i "s/^file_number=.*/file_number=${next_file_number}/" "$SCRIPT_FILE"


################################################################
#                                                              SHUTDOWN LOCAL AI MODEL
################################################################


# This tells Ollama to unload the model from memory.
echo -e "${PURPLE}Shutting down Ollama model: ${AI_MODEL}${RESET}"

curl -s "$OLLAMA_URL" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${AI_MODEL}\",\"prompt\":\"\",\"stream\":false,\"keep_alive\":0}" >/dev/null || true


################################################################
#                                                              BUILD SUMMARY
################################################################


echo
echo -e "${GREEN}Build complete.${RESET}"
echo "Build artifacts:"
echo "Plan directory:          ${PLAN_DIR}"
echo "Binary plan:             ${PLAN_DIR}/tfplan-${file_number}"
echo "Text plan:               ${PLAN_DIR}/tfplan-${file_number}.txt"
echo "JSON plan:               ${PLAN_DIR}/tfplan-${file_number}.json"
echo "Security findings:       $SECURITY_FILE"
echo "Clean security findings: $CLEAN_SECURITY_FILE"
echo "AI doc:                  $AI_DOC_FILE"
echo "Next file number:        ${next_file_number}"


################################################################
#                                                              SLOW ASCII OUTRO
################################################################


# Prints the ASCII art slowly at the end of the build.
# Change OUTRO_DELAY to control the speed.
# Lower number = faster.
# Higher number = slower.
OUTRO_DELAY="0.10"

GREEN="\033[1;32m"
RESET="\033[0m"

slow_print_art() {
  local delay="${1:-0.10}"

  while IFS= read -r line; do
    printf "%b%s%b\n" "$GREEN" "$line" "$RESET"
    sleep "$delay"
  done
}

echo
echo -e "${PURPLE}Rendering build outro...${RESET}"
echo

slow_print_art "$OUTRO_DELAY" <<'ASCII_ART'
⠀⠀⠀⠀⣏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠴⠦⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣶⣋⢀⣨⠇⢀⣯⠀⠀⠀⠀⠀⠀
⠀⠀⢀⡖⠚⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠘⠒⠚⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠈⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠟⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⠒
⠀⠀⠀⠉⠳⠒⡇⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⢨⣙⡖⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⢀⣀⣀⣤⠾⠀
⠀⠀⠀⠀⠀⠀⠉⠉⣿⠗⠀⠀⠀⢠⡖⠋⠲⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⣟⠋⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢰⣋⠁⠀⠀⠀⠀⠀⠳⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣾⠁⠀⠀⠀⠀⠀⠀
⠀⠀⡶⠋⠉⠓⠋⠁⠀⠀⠀⠀⠀⠀⠾⡇⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⢄⣀⣤⡄⠀⣀⢀⠀⠀⠀⠀⠀⠀⣄⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣤⡤⠖⠋⠀⠀⠀⠀⠀⠀⠀
⠀⠀⣷⠀⠀⠀⢀⡤⠴⠋⠉⠳⠛⠒⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⢀⡗⠈⠉⠀⠉⠉⠉⣏⣳⢀⣀⣀⡤⠞⠉⠉⠓⠒⠻⡆⠀⠀⣀⠀⢀⡤⠶⠖⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠴⠚⠁⣀⡀⠀⠘⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⠯⣄⠀⠀⠀⠀⠀⠀⠈⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠋⠙⠚⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠀⠀⠀
⠀⠀⡏⠀⠐⠚⢆⣸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠈⣧⠀⠀⠀⠀⠀⠀⢀⡠⠤⣤⢤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣤⠖⠚⠩⡷⢤⡶⠶⢚⣩⠵⠋⠀⠀⠀
⠀⠀⠉⠕⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⠀⢠⣏⡶⠓⠉⣩⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡀⢀⣖⠓⠚⠀⠀⡟⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⢩⣿⠂⡤⣤⣻⣾⡆⣤⠼⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡇⢀⣄⠟⠀⠀⣀⡼⠁⠀⠀⠀⠀⠀⠀
⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⠿⣭⣁⡤⠭⠝⢿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⡿⠒⣊⡀⠀⢀⣨⠟⠀⠀⠀⠀⠀⠀⠀⠀
⠉⠑⢦⠀⠀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠖⠚⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⠟⠛⠉⠉⠁⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠈⠉⠉⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⢤⡤⠶⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⣴⣫⣟⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⣖⠚⣦⠀⠀⢀⡀⢠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡾⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⣠⢖⠾⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢶⡚⣹⠶⣺⠉⠿⠚⠉⠉⠿⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡞⠀⣧⠀⠀⠀⠀⣀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠋⠯⣄⢀⡀⠀⠀⢀⡤⢤⡀⠀⢶⠲⣤⠴⣣⣧⠴⠚⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡾⠁⠀⠿⠒⠛⠉⠉⠉⠉⠀⠀⣠⡾⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠈⠉⠙⠦⠖⠋⢼⣟⢁⣀⣸⠇⠀⠀⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⣾⣛⠛⠛⢳⣦⣄⠀⠀⠀⠀⠀⠀⢀⣴⡋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠸⠟⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⣻⣻⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠈⠉⠳⠦⣄⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣠⡞⢠⣤⣤⣈⠙⠻⠻⣿⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⣀⣹⣷⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣡⠈⠉⠀⠐⠿⠅⠘⠋⠀⠀⠀⣟⢿⣿⣿⣿⣿⢀⠀⠀⣆⠀⠀⠀⠛⢯⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⠟⠀⠀⠀⠀⠀⢀⠐⣄⠀⠀⠀⠀⣸⠀⢻⣿⣿⣿⣾⣇⢀⣿⣦⡀⣶⣄⡀⠙⢷⡄⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡞⠲⡄⠀⠀⠀⢹⡈⢧⠈⠧⠀⠀⢠⢇⣠⢬⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣽⣦⡀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡞⠀⠀⠀⠀⠀⠀⠐⠇⠚⠃⠀⠀⠀⠘⠉⠀⣿⡟⣻⣿⣿⣿⣿⣿⡿⠿⢿⣿⣿⡿⠿⠿⠿⠷⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⠀⠘⢿⣽⣃⣽⠳⠋⢿⣿⣿⣿⢧⠈⠉⢿⣿⣄⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠯⣓⠒⠤⠤⠤⠤⠤⠤⠤⠤⠖⠉⢨⣹⣿⣿⠟⠙⠉⠁⠀⠸⢿⣿⣿⣶⣶⣶⣤⣻⣿⣦⡀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠓⢦⣄⠀⠀⠀⠀⠀⠀⠀⢀⡏⠈⢰⡯⠀⠀⠀⠀⠀⠀⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⠀⠀⠀⠀⠀⠀⠈⠀⢀⣿⢼⡀⡀⠀⣠⣧⡀⢸⣿⣿⣿⣿⣿⠿⠿⠛⠛⠿⠿⠦⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣇⡠⡴⢲⠒⡖⣶⠲⡾⢦⣬⣿⣿⣤⡟⠀⠙⢾⣿⣿⣿⣿⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⢾⠛⠁⡇⡇⠈⡄⣥⢿⠀⡇⢸⡆⡅⠙⢹⡙⡷⣦⠀⠈⠻⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣧⢸⠀⡇⠀⢳⠀⡇⢯⢸⠀⣇⢸⡀⡇⢸⠠⣇⠇⡾⠀⠀⠀⠈⠙⠛⠛⠛⠛⠛⠿⠆⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⡿⣼⢸⠀⡇⣆⣸⣤⠷⠚⠛⠛⠛⠦⣇⣸⢸⠀⢘⢰⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⢸⣾⣤⣾⠟⠋⠀⠀⠀⠀⠀⠀⠀⠈⠻⣿⢴⣘⣸⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⢞⡵⠋⠁⠀⡤⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⡶⣾⣿⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣞⡼⠋⠀⠀⠀⢸⡇⠀⡤⢤⠀⢀⣠⠤⠦⢤⣈⢷⣀⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠋⠀⠀⠀⠀⠀⣼⠀⢸⡟⢻⡴⢫⠔⢊⣉⡓⢌⢻⡗⢻⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠁⠀⠀⠀⢠⡦⢰⡇⠀⢸⣷⣾⠁⡏⢰⢟⠉⣻⡌⡇⣷⣾⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⠟⠀⠀⠀⠀⣀⣨⡧⢺⢃⣠⣿⠀⢸⡄⢧⡈⣎⡓⠋⡰⣱⡇⠀⡟⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⣀⣤⠴⠚⠋⠁⡀⢳⢸⣿⣿⣿⣿⣽⣿⣶⣬⣉⣫⣽⣾⣿⣷⢯⡻⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣽⠟⠉⠀⣴⠂⠀⠀⢿⣎⢿⣿⣿⣿⣿⡸⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠙⡿⢽⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡏⠀⢀⡼⠃⠀⠀⠀⠀⠉⠻⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⢸⡇⠀⠉⠛⢿⠶⣄⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠇⣠⠞⠀⠀⠀⠀⠀⠀⠀⠀⠹⣿⣿⣿⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠈⠑⢮⣳⡦⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⡴⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⡧⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠉⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡽⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⠴⠂⣠⡶⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡟⠀⠀⠀⠀⠀⠀⠀⢀⡤⠖⠛⠉⢀⣴⠚⢡⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠁⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⠁⠀⠀⠀⠀⠀⣠⡶⠋⠀⠀⠀⣰⣿⡇⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⢽⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⢸⣿⠀⠀⠀⠀⣠⣾⡟⢁⣀⣤⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣦⣿⣦⡀⠀⣰⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⣀⣦⠾⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⠿⠛⢛⣿⢿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⢿⣿⣿⠟⠋⡵⠃⠀⣠⠎⡼⡎⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⣻⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣹⣏⠀⢀⡞⠁⠀⣰⠃⢠⣧⣷⡿⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠳⠿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠁⣿⡾⠋⠀⠀⢸⡟⠀⠸⡟⢯⠀⠀⠀⠈⢭⣙⠛⣿⣿⣿⣿⣿⣿⡏⠀⠀⠀⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣏⠀⠀⠀⢠⠈⠀⠀⠀⠙⢆⠳⣄⠀⠀⠀⢀⣾⣿⣿⠟⠉⠉⠉⠀⠀⠀⠀⠈⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⢠⠏⠀⠀⠀⠀⠀⠈⠃⠉⢣⣄⣠⣿⣿⣿⣅⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡿⠀⢠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠙⢦⡉⠛⠛⢻⣿⠛⠿⠆⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣧⠶⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠲⣄⣸⣿⠀⠀⠀⠠⡄⠀⠀⠀⠀⠀⣾⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⢲⣿⣧⣄⡀⠀⠀⠙⢦⠀⠀⠀⢠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣾⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⡟⡆⠈⠁⠀⠀⠀⠈⢳⡀⠀⣾⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣯⠁⠙⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⡇⠀⠀⠀⠀⠀⠀⠀⠹⣞⢻⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢈⣷⣄⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢷⡇⠀⠀⠀⠀⠀⠀⠀⠀⠘⢿⡅⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
ASCII_ART

################################################################
#                                                              SLOW ASCII OUTRO
################################################################


OUTRO_DELAY="0.10"

slow_print_art() {
  local delay="${1:-0.10}"

  while IFS= read -r line; do
    printf "%b%s%b\n" "$GREEN" "$line" "$RESET"
    sleep "$delay"
  done
}

echo
#echo -e "${PURPLE}Rendering build outro...${RESET}"
echo

slow_print_art "$OUTRO_DELAY" <<'ASCII_ART'
██╗   ██╗██████╗ ███╗   ██╗    ██████╗ ██╗   ██╗██╗██╗  ████████╗"
██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██║   ██║██║██║  ╚══██╔══╝"
██║   ██║██████╔╝██╔██╗ ██║    ██████╔╝██║   ██║██║██║     ██║"
╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██╔══██╗██║   ██║██║██║     ██║"
 ╚████╔╝ ██║     ██║ ╚████║    ██████╔╝╚██████╔╝██║███████╗██║"
  ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═╝"
✅ VPN Built Successfully
ASCII_ART