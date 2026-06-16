

# plan_version = ""



# cd ..

# terraform init

# terraform validate

# terraform apply -auto-approve


#!/usr/bin/env bash

set -euo pipefail

if ! command -v terraform >/dev/null 2>&1; then
  echo "Terraform is not installed or not in PATH"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Git is not installed or not in PATH"
  exit 1
fi



