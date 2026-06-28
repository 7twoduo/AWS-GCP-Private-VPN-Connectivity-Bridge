#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[1;32m"
PURPLE="\033[1;35m"
RED="\033[1;31m"
RESET="\033[0m"

file_number=2

# Creates an absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_FILE="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"

echo "Script directory: $SCRIPT_DIR"

ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
echo "Root directory: $ROOT_DIR"

DESTROY_DIR="${SCRIPT_DIR}/destroy_plan"
echo "Destroy plan directory: $DESTROY_DIR"

mkdir -p "$DESTROY_DIR"

echo "Moving to Terraform root directory..."
cd "$ROOT_DIR"

echo "Initializing Terraform..."
terraform init

echo "Validating Terraform configuration..."
terraform validate

echo "Formatting Terraform files..."
terraform fmt -recursive

echo "Creating Terraform destroy plan..."
terraform plan -destroy -out="${DESTROY_DIR}/destroyplan-${file_number}"

echo "Saving readable destroy plan..."
terraform show -no-color "${DESTROY_DIR}/destroyplan-${file_number}" > "${DESTROY_DIR}/destroyplan-${file_number}.txt"

echo "Saving destroy plan JSON..."
terraform show -json "${DESTROY_DIR}/destroyplan-${file_number}" > "${DESTROY_DIR}/destroyplan-${file_number}.json"

echo
echo "Destroy plan created:"
echo "Binary plan: ${DESTROY_DIR}/destroyplan-${file_number}"
echo "Text plan:   ${DESTROY_DIR}/destroyplan-${file_number}.txt"
echo "JSON plan:   ${DESTROY_DIR}/destroyplan-${file_number}.json"
echo

# Needlessly Complex
# read -p "Type Destroy to push this infrastructure tear down plan: " confirm

# if [ "$confirm" != "Destroy" ]; then
#   echo "Destroy cancelled."
#   exit 0
# fi

echo "Applying destroy plan..."
terraform apply "${DESTROY_DIR}/destroyplan-${file_number}"

next_file_number=$((file_number + 1))

echo "Updating next destroy plan number..."
sed -i "s/^file_number=.*/file_number=${next_file_number}/" "$SCRIPT_FILE"

echo
echo "Next file number: ${next_file_number}"


################################################################
#                                                              SLOW DESTROY ASCII OUTRO
################################################################


# Prints the destroy ASCII art slowly at the end of the destroy workflow.
# Lower DESTROY_OUTRO_DELAY = faster.
# Higher DESTROY_OUTRO_DELAY = slower.
DESTROY_OUTRO_DELAY="0.15"

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"

slow_print_destroy_art() {
  local delay="${1:-0.15}"
  local line_number=0

  local colors=(
    "$RED"
    "$YELLOW"
    "$GREEN"
    "$CYAN"
    "$BLUE"
    "$PURPLE"
    "$WHITE"
  )

  while IFS= read -r line; do
    local color_index=$((line_number % ${#colors[@]}))
    local color="${colors[$color_index]}"

    printf "%b%s%b\n" "$color" "$line" "$RESET"

    line_number=$((line_number + 1))
    sleep "$delay"
  done
}

echo
echo -e "${PURPLE}Rendering destroy outro...${RESET}"
echo

slow_print_destroy_art "$DESTROY_OUTRO_DELAY" <<'DESTROY_ASCII_ART'
⣙⡿⠋⠁⠐⠁⠀⠀⠀⠀⠀⠀⢻⡇⠀⠀⢱⠀⠀⠳⡀⠀⠀⠀⢂⠈⠓⢦⡀⠀⠀⠀⠀⠀⠀⠀⠙⢦⡀⠀⠀⠀⠀⠀⠀⠀⠙⠲⢄⡀⠀⠀⠀⠉⠑⠢⣄⡉⠓⠦⣄⡀⠀⠁⠂
⡢⠀⠊⠀⠀⠀⠈⢇⠀⠀⠀⠀⠀⢧⠀⠀⠀⢣⡀⠀⠱⣄⠀⠀⠈⢆⠀⠀⠙⠒⢄⠀⠀⠀⠐⢤⡀⠀⠑⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠢⢄⠀⠀⠀⠀⠀⠉⠑⠂⠤⣉⠒⠤⡀
⠁⣀⣶⠁⠀⠀⠀⠸⣦⡀⠀⠀⠀⠀⠂⠀⠀⠀⠑⢄⠀⠘⢦⡀⠀⠀⢢⠀⠀⠈⠠⡁⠢⣀⠀⠀⠈⠢⢀⠀⠁⠀⠀⠀⠀⠀⠈⠢⡀⠀⠑⠦⡑⢦⡀⠀⠀⠀⠀⠀⠀⠀⠉⠐⠀
⣛⣻⠏⡀⠀⠀⠀⠀⠈⠻⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠣⡀⠈⠻⣄⠀⠀⠣⡀⠀⠀⠀⠀⠀⠙⠠⠀⠀⠀⠱⢄⡀⠀⠀⠀⠀⠀⠀⠈⠣⡀⠀⠈⡲⢝⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀
⠽⠋⠀⠀⠀⡀⢠⠀⢰⡆⠈⠻⢷⣤⣀⡀⠀⠀⠀⠀⠀⠈⠃⠄⠀⠷⢄⠀⠐⢄⠀⠀⢀⠀⠒⢀⠀⠀⠀⠀⠀⠉⠒⠤⡀⠀⠀⠀⠀⠀⠈⢢⡀⠈⠢⡛⣿⣷⡄⠀⠀⠀⠀⠀⠀
⠁⠀⠀⠀⠀⢧⠸⡀⢸⠁⠀⠀⠀⠉⠻⣿⣶⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢦⡀⠀⡀⠀⠑⢦⣀⠁⠀⠀⠀⢀⠀⠀⠀⡈⠁⠀⠀⠀⠀⠀⠀⠙⢆⠀⠘⢾⣿⣿⡄⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠸⡀⠇⢸⠀⠀⠐⠀⠀⠀⠀⠈⠙⠻⠷⣶⣄⡀⠀⠀⠀⠀⠀⠀⠙⠦⡀⠀⠀⢀⡑⠈⠢⢄⡀⠀⠑⢦⡀⠈⠂⠀⠀⠀⠀⠀⠀⠀⠈⠳⡄⠀⠙⡿⡷⡄⠀⠄⠀⠀
⠀⠀⠀⠀⠀⠀⢇⠰⢸⡆⠀⠀⠀⠀⠀⠀⠀⠀⠈⢆⠀⠉⠉⠓⠢⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠉⠲⣄⡀⠉⠓⠦⡀⠙⢆⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢦⠀⠈⠏⠈⢄⠀⠢⠀
⠀⠀⡀⠀⠀⠀⠘⣆⠈⡇⠀⢸⠀⠀⠀⠀⠀⠀⠀⠈⢂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠑⠶⡄⠀⠀⠀⠀⠑⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢷⡄⠀⠀⠀⠂⠀⠁
⠀⠸⠀⠀⠀⠀⠀⠸⣆⠡⠀⠀⠀⠀⢠⡀⠀⠀⠀⠀⠀⠳⡀⠀⠀⠀⠀⠀⠀⠀⠂⡀⢀⠀⠀⠠⣀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠣⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠳⡄⠀⠀⠀⠀⠀
⠀⡇⠀⠀⠀⠀⠀⢀⢹⡆⠀⠀⠆⠀⢸⣷⣄⠀⠀⠀⠀⠀⠑⡄⠀⠀⠂⠀⠀⠀⠀⠑⡄⢳⣶⡄⠈⠙⠒⠂⠀⠀⡀⠀⠀⠀⠀⠀⠈⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣆⠀⠀⠀⠀
⢰⠀⠀⠀⠀⠀⠀⠸⠀⢻⡄⠀⠀⠀⠈⠛⠛⠓⠀⠀⠀⠀⠀⠈⢆⠀⠀⠁⠀⠀⢀⠀⠈⢆⠉⢀⣾⠀⠀⠀⠀⠀⢻⣷⣄⠀⡀⠀⠀⠀⠙⢦⠀⠀⠀⠀⠀⠀⠀⠀⠘⣄⠀⠀⠀
⠈⠀⠀⠀⠀⠀⠀⠀⡆⠀⢳⡀⠀⠠⠀⢠⣾⠀⠀⠀⠀⠀⠀⢄⠀⠑⠄⠀⠀⠘⣦⡑⢄⡀⠡⢸⣿⣇⡀⠀⠀⢀⣿⣿⡿⢀⣿⡀⠀⠀⠀⠀⠱⡄⠀⠀⠀⠀⢀⠀⠀⠈⠂⠀⠀
⡆⠀⠀⡀⠀⠀⠀⠀⡇⠀⠆⠣⠀⠀⡆⢸⣿⡄⠀⠀⠀⣦⠀⠀⣀⠀⠈⠀⠀⠀⠈⢿⣦⣔⢢⡈⢿⣿⣿⣿⣿⣿⡿⠛⠀⣼⣿⣇⠀⠀⠀⠀⠀⠈⠢⡀⠀⠀⠈⢆⠀⠀⠀⠀⠀
⡇⠀⠀⢤⡄⠀⠀⠀⠰⠀⠰⠀⠀⠀⠰⠈⢻⣿⣦⣤⣼⣿⣧⣄⠘⢿⣷⣦⣀⠀⠀⠈⢻⣿⣿⣿⣶⣄⡉⠉⠛⠉⠀⣠⣾⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠈⠂⠀⠀⠀⢂⠀⠀⠀⠀
⡇⠀⢤⢼⡇⠀⢀⠀⠐⡄⠀⢃⠀⠀⠀⡘⡤⠙⠛⠻⠛⠉⢀⣿⣿⢰⣿⣿⣿⣷⣦⣀⠀⠹⣿⣿⣿⣿⣿⣿⣶⣶⣿⣿⣿⣿⣿⣿⡄⢰⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢄⠀⠀⠀
⠀⠀⢠⠷⣧⠀⠈⡀⠀⠃⠁⠘⡄⠀⠀⠀⢻⣦⣄⣀⣀⣴⣿⣿⡏⣼⣿⣿⣿⣿⣿⣿⣷⣶⣌⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢸⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠄⠀⠀
⠀⠀⠚⣈⣿⣀⠀⠽⠀⠐⠀⠀⠙⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⡿⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⢸⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⡄⠀
⠀⠀⡀⢿⣻⣿⡀⠰⣶⠀⠐⡄⠀⠀⠀⠀⠈⡜⣿⣿⣿⣿⣿⠁⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢸⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⡀
⠀⠀⢰⠟⠛⢫⡇⠀⣿⣧⠀⢻⡀⠀⠀⠀⠀⠹⣿⣿⣿⣿⣿⣄⠘⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣸⣿⣿⠀⠀⠀⢠⡀⠈⢳⣄⠀⠀⠀⠀⠐
⡂⠀⢱⣿⠿⠷⢬⣆⢹⣿⡆⠈⣿⡀⠀⠀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣶⣍⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⢸⣧⠀⠘⣿⣷⣦⡀⠀⠐
⡇⠠⢿⣶⣀⢶⣾⣿⡆⢻⡷⠀⠱⣷⠀⠀⢀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⢠⣷⠀⠀⢸⣿⣧⡀⢻⣿⣿⣿⣦⡀
⡙⠀⠀⠙⣣⣹⠳⠾⣛⣆⢻⣥⣀⠁⣁⠀⠸⡀⠀⠀⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⢀⣿⣿⠠⠀⣼⣿⣿⣧⠀⣿⣿⣿⣿⠇
⣯⠀⢀⠠⣽⣿⣿⣿⣾⣿⣿⣿⣿⣂⣉⠄⠀⣧⠀⠀⠀⢌⠻⣿⣿⣿⣿⣛⡉⢙⣯⣭⣭⣽⣛⣻⡿⢿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⣿⣿⣿⡄⠀⣿⣿⣿⣿⣷⣿⣿⣿⣿⢸
⣏⡁⠀⢤⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⣿⣄⠀⠀⠸⣧⠈⠻⣿⣿⣿⣿⣦⣟⣛⣛⣛⣛⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀⢸⣿⣿⣿⡇⠀⣿⣿⣿⣿⣿⣿⣿⣿⣇⣿
⢏⡁⡐⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⢸⣿⡄⠀⠀⣿⣦⢡⠈⠻⣿⣿⣿⡛⠿⠿⠿⢛⣻⣿⣿⣿⣿⣿⣿⣿⡿⠃⠀⠀⠀⠀⣿⣿⣿⣿⣇⠀⣿⣿⣿⣿⣿⣿⣿⣿⣽⣿
⢖⡔⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠸⠿⣿⡀⠀⢻⣿⣇⠢⠀⠈⠻⣿⣿⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢧⣿⡿
⣉⢰⠟⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⣻⣿⣿⣄⢸⣿⣟⣧⣳⡀⠀⠘⢿⣿⣿⣿⣿⣿⣿⣿⣿⠿⢋⣀⡀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣼⣿⡇
⢹⢿⠶⣠⣿⣿⣿⣿⣿⣿⡯⢛⣿⣿⣿⣻⣿⣿⣿⣿⣿⣿⡌⣿⣿⣿⣿⣿⣄⠈⣄⠙⠻⣿⣿⣿⠿⠛⣉⣴⣿⣿⣭⡴⠆⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣿⣿⡇
⣭⣿⡟⣯⣽⣿⢼⣿⣿⣯⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣼⣿⣿⣿⣿⣿⣆⠹⣿⣶⣶⣤⣤⣤⣾⣿⣿⣿⣿⣿⣷⡆⡀⣦⡀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢰⣿⣿⠀
⣟⢙⣈⣿⣿⣧⣡⣿⣿⣿⢿⣿⣿⣿⣿⣿⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⡇⣿⣿⣦⣈⠙⠻⢿⣿⣿⣿⣿⣿⣿⣿⡟⣾⣿⣿⠀
⣿⡿⠿⣿⣿⣿⣰⣿⢟⡁⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⡀⢁⢻⣿⣿⣧⣷⡀⠀⠉⠻⣿⣿⣿⣿⣿⢷⣿⣿⡇⠀
⣏⣍⡹⣿⠻⢿⠟⣡⡿⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⣿⢸⢸⣿⣿⣿⣿⢻⡆⠸⣦⣼⣿⣿⣿⡿⣼⣿⣿⢳⣇
DESTROY_ASCII_ART


################################################################
#                                                              SLOW DESTROY ASCII OUTRO
################################################################


DESTROY_OUTRO_DELAY="0.10"

slow_print_destroy_success() {
  local delay="${1:-0.10}"

  while IFS= read -r line; do
    printf "%b%s%b\n" "$GREEN" "$line" "$RESET"
    sleep "$delay"
  done
}

echo
echo -e "${PURPLE}Rendering destroy success banner...${RESET}"
echo

slow_print_destroy_success "$DESTROY_OUTRO_DELAY" <<'DESTROY_SUCCESS_ART'

██╗   ██╗██████╗ ███╗   ██╗
██║   ██║██╔══██╗████╗  ██║
██║   ██║██████╔╝██╔██╗ ██║
╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║
 ╚████╔╝ ██║     ██║ ╚████║
  ╚═══╝  ╚═╝     ╚═╝  ╚═══╝

██████╗ ███████╗███████╗████████╗██████╗  ██████╗ ██╗   ██╗███████╗██████╗
██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗╚██╗ ██╔╝██╔════╝██╔══██╗
██║  ██║█████╗  ███████╗   ██║   ██████╔╝██║   ██║ ╚████╔╝ █████╗  ██║  ██║
██║  ██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║  ╚██╔╝  ██╔══╝  ██║  ██║
██████╔╝███████╗███████║   ██║   ██║  ██║╚██████╔╝   ██║   ███████╗██████╔╝
╚═════╝ ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝╚═════╝

🔥 VPN Destroyed Successfully
DESTROY_SUCCESS_ART