# Scripts Documentation — Multi-Cloud VPN Routing Project

This document explains the project automation scripts in detail. The scripts are important because they turn the Terraform lab into a repeatable build, security-review, evidence-generation, and teardown workflow.

---

## Script Inventory

| Script | Purpose |
|---|---|
| `build_everything.sh` | Runs the full Terraform build, security scan, plan/apply, and AI documentation workflow |
| `destroy_everything.sh` | Generates destroy plans and tears down the infrastructure |
| `prompt.md` | Controls how the local AI model converts raw scanner output into a polished security report |
| `version_control.sh` | Lightweight helper for checking Terraform/Git prerequisites |

---

## `build_everything.sh`

### Purpose

`build_everything.sh` is the primary automation script for the project.

It does not only run Terraform. It creates a full evidence trail:

```text
dependency checks
  ↓
Terraform init / validate / fmt
  ↓
local security scanning
  ↓
clean scanner output
  ↓
Terraform plan files
  ↓
Terraform apply
  ↓
AI-generated security report
  ↓
build artifact summary
```

### Main Configuration

The script uses:

```bash
file_number=2
PLAN_DIR="${SCRIPT_DIR}/build_plan"
AI_MODEL="gemma4:12b"
OLLAMA_URL="http://localhost:11434/api/generate"
PROMPT_FILE="${SCRIPT_DIR}/prompt.md"
```

The `file_number` controls the artifact version. Each run creates files such as:

```text
tfplan-2
security-findings-2.txt
security-findings-clean-2.txt
ai-security-doc-2.md
```

At the end of the run, the script increments `file_number` for the next build.

### Dependency Checks

The script checks for:

```text
Terraform
grep
awk
Ollama
Gitleaks
TFLint
Checkov
Trivy
Docker
```

If a dependency is missing, the script prints the missing dependency list and exits without treating the missing scanner as a vulnerability.

### Ollama Model Validation

The script validates the local AI model:

```bash
ollama list | awk 'NR > 1 {print $1}' | grep -Fxq "$AI_MODEL"
```

If the model is missing, the script exits with:

```text
Go install gemma4:12b
```

### Docker Validation

Docker is required because KICS and Terrascan run as containers.

```bash
docker info
```

If Docker is installed but not running, the script stops and tells the operator to start Docker Desktop.

### Terraform Build Workflow

The script moves from `scripts/` to the Terraform root and runs:

```bash
terraform init
terraform validate
terraform fmt -recursive
```

Then it creates a binary plan, text plan, and JSON plan:

```bash
terraform plan -out="${PLAN_DIR}/tfplan-${file_number}"
terraform show -no-color "${PLAN_DIR}/tfplan-${file_number}" > "${PLAN_DIR}/tfplan-${file_number}.txt"
terraform show -json "${PLAN_DIR}/tfplan-${file_number}" > "${PLAN_DIR}/tfplan-${file_number}.json"
```

### Security Scanning Workflow

The script writes all raw scan output to:

```text
scripts/build_plan/security-findings-N.txt
```

It then creates a cleaned copy:

```text
scripts/build_plan/security-findings-clean-N.txt
```

Security sections include:

| Check | Purpose |
|---|---|
| Terraform Format Check | Detects formatting drift |
| Terraform Validate | Confirms Terraform configuration validity |
| Secret Scan | Grep-based secret pattern search |
| Gitleaks | Secret scanning |
| Public Exposure Scan | Searches for `0.0.0.0/0`, `::/0`, and public IAM patterns |
| IAM Privilege Scan | Searches for wildcard/admin-style IAM patterns |
| TFLint | Terraform linting |
| Checkov | IaC policy scanning |
| Trivy | HIGH/CRITICAL IaC misconfiguration scanning |
| KICS | Containerized IaC scanning |
| Terrascan | Containerized Terraform scanning |

### Output Cleanup

The script uses a `clean_file` function to remove ANSI escape codes, terminal control characters, and trailing whitespace from scanner output.

This matters because raw scanner output is often noisy and not clean enough for Markdown reports.

### AI Security Documentation

After scanning, the script combines:

```text
scripts/prompt.md
+
security-findings-clean-N.txt
```

Then it sends that combined prompt to Ollama using `curl` and `jq`.

The AI output is saved as:

```text
scripts/build_plan/ai-security-doc-N.md
```

This file is intended to be a leadership-readable and engineer-readable Markdown security review.

### Build Artifacts

Expected output:

```text
scripts/build_plan/
├── tfplan-N
├── tfplan-N.txt
├── tfplan-N.json
├── security-findings-N.txt
├── security-findings-clean-N.txt
├── ai-request-prompt-N.txt
└── ai-security-doc-N.md
```

### Important Safety Note

The current script automatically applies the generated Terraform plan:

```bash
terraform apply "${PLAN_DIR}/tfplan-${file_number}"
```

For production-style safety, re-enable a manual approval prompt before applying.

Recommended safer pattern:

```bash
read -p "Type Apply to deploy this Terraform plan: " confirm

if [ "$confirm" != "Apply" ]; then
  echo "Apply cancelled."
  exit 0
fi
```

---

## `prompt.md`

### Purpose

`prompt.md` is the instruction file used by the local AI model.

Its job is to force the AI-generated security report to stay evidence-based.

### What the Prompt Enforces

The prompt tells the AI to:

- transform raw Terraform security pipeline output into a clean Markdown report
- avoid hallucinated findings
- avoid hallucinated architecture
- avoid counting skipped tools as vulnerabilities
- deduplicate repeated findings
- count only actual detected issues
- separate PASS checks from security findings
- include architecture only when supported by evidence
- include an apply/no-apply decision based on highest detected severity
- avoid generic best practices not tied to findings

### Why This Matters

Raw scanner output is usually noisy. The prompt acts as a report-generation control layer so the final document is more useful for:

- technical review
- leadership review
- portfolio presentation
- interview evidence
- apply/no-apply decisions

---

## `destroy_everything.sh`

### Purpose

`destroy_everything.sh` handles controlled teardown.

It generates a destroy plan before removing infrastructure, then exports the plan into multiple evidence formats.

### Workflow

```text
Terraform init
  ↓
Terraform validate
  ↓
Terraform fmt
  ↓
Terraform destroy plan
  ↓
readable destroy plan export
  ↓
JSON destroy plan export
  ↓
Terraform apply destroy plan
  ↓
artifact number increment
```

### Commands Run

```bash
terraform init
terraform validate
terraform fmt -recursive
terraform plan -destroy -out="${DESTROY_DIR}/destroyplan-${file_number}"
terraform show -no-color "${DESTROY_DIR}/destroyplan-${file_number}" > "${DESTROY_DIR}/destroyplan-${file_number}.txt"
terraform show -json "${DESTROY_DIR}/destroyplan-${file_number}" > "${DESTROY_DIR}/destroyplan-${file_number}.json"
terraform apply "${DESTROY_DIR}/destroyplan-${file_number}"
```

### Destroy Artifacts

Expected output:

```text
scripts/destroy_plan/
├── destroyplan-N
├── destroyplan-N.txt
└── destroyplan-N.json
```

### Important Safety Note

The manual confirmation block is currently commented out. That means the script automatically applies the destroy plan.

For safer operation, restore the confirmation gate:

```bash
read -p "Type Destroy to push this infrastructure tear down plan: " confirm

if [ "$confirm" != "Destroy" ]; then
  echo "Destroy cancelled."
  exit 0
fi
```

---

## `version_control.sh`

### Purpose

This script is a small helper for checking local tooling before running Terraform or Git-based workflows.

It currently validates:

```text
Terraform is installed
Git is installed
```

This can later evolve into a stronger repository hygiene script that checks:

- active Git branch
- uncommitted changes
- Terraform formatting
- Terraform validation
- last plan number
- evidence artifact status

---

## Recommended Script Improvements

| Improvement | Why It Matters |
|---|---|
| Add apply confirmation | Prevents accidental infrastructure deployment |
| Add destroy confirmation | Prevents accidental teardown |
| Add environment argument | Supports dev/stage/prod workflows |
| Add remote backend check | Prevents unsafe local-state usage |
| Add state-lock validation | Reduces concurrent apply risk |
| Add scanner severity gate | Blocks apply on Critical/High findings |
| Add evidence archive step | Preserves plan and scanner artifacts |
| Add checksum generation | Verifies evidence file integrity |
| Add CI/CD mode | Allows GitHub Actions or GitLab CI integration |

---

## Recommended CI/CD Translation

The local scripts can become a CI/CD pipeline:

```text
Pull Request
  ↓
terraform fmt -check
  ↓
terraform validate
  ↓
terraform plan
  ↓
security scanning
  ↓
AI/security report generation
  ↓
artifact upload
  ↓
manual approval
  ↓
terraform apply
```

Destroy workflow should remain separated behind a stronger approval gate.

---

## Final Script Summary

The script system is one of the strongest parts of this project because it proves engineering maturity beyond manual Terraform commands.

It shows:

- repeatable build workflow
- dependency validation
- Terraform plan evidence
- security scanning evidence
- AI-assisted documentation
- artifact versioning
- destroy-plan evidence
- cloud cost cleanup discipline

The main hardening needed is to restore manual approval gates before apply and destroy.
