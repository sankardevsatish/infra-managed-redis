#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# Terraform Managed Redis - Deployment Script
# ──────────────────────────────────────────────
# Replaces the GitHub Actions workflow with a
# standalone script for local or CI/CD execution.
#
# Usage:
#   ./deploy.sh plan   [env]     # Plan changes (default: dev)
#   ./deploy.sh apply  [env]     # Apply changes
#   ./deploy.sh destroy [env]    # Destroy infrastructure
#
# Prerequisites:
#   - Terraform >= 1.7.0 installed
#   - Azure CLI installed and logged in
#   - Environment variables set (see .env.example)
# ──────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="${SCRIPT_DIR}/components/managed-redis"
ENVIRONMENTS_DIR="${SCRIPT_DIR}/environments"

# ──────────────────────────────────────────────
# DEFAULTS
# ──────────────────────────────────────────────
TF_VERSION="${TF_VERSION:-1.7.0}"
ACTION="${1:-plan}"
ENVIRONMENT="${2:-dev}"

# ──────────────────────────────────────────────
# COLOUR OUTPUT
# ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ──────────────────────────────────────────────
# LOAD ENVIRONMENT VARIABLES
# ──────────────────────────────────────────────
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  log_info "Loading .env file"
  set -a
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/.env"
  set +a
fi

# ──────────────────────────────────────────────
# VALIDATE INPUTS
# ──────────────────────────────────────────────
validate_inputs() {
  # Validate action
  case "${ACTION}" in
    plan|apply|destroy) ;;
    *)
      log_error "Invalid action: '${ACTION}'. Must be one of: plan, apply, destroy"
      echo ""
      echo "Usage: $0 <action> [environment]"
      echo "  action:      plan | apply | destroy"
      echo "  environment: dev (default) | qa | live"
      exit 1
      ;;
  esac

  # Validate environment file exists
  local tfvars="${ENVIRONMENTS_DIR}/${ENVIRONMENT}.tfvars"
  if [[ ! -f "${tfvars}" ]]; then
    log_error "Environment file not found: ${tfvars}"
    log_error "Available environments:"
    ls -1 "${ENVIRONMENTS_DIR}"/*.tfvars 2>/dev/null | xargs -I{} basename {} .tfvars | sed 's/^/  - /'
    exit 1
  fi

  # Validate required environment variables
  local missing=()
  [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]       && missing+=("ARM_SUBSCRIPTION_ID")
  [[ -z "${ARM_TENANT_ID:-}" ]]             && missing+=("ARM_TENANT_ID")
  [[ -z "${ARM_CLIENT_ID:-}" ]]             && missing+=("ARM_CLIENT_ID")
  [[ -z "${BACKEND_RESOURCE_GROUP:-}" ]]    && missing+=("BACKEND_RESOURCE_GROUP")
  [[ -z "${BACKEND_STORAGE_ACCOUNT:-}" ]]   && missing+=("BACKEND_STORAGE_ACCOUNT")
  [[ -z "${BACKEND_CONTAINER:-}" ]]         && missing+=("BACKEND_CONTAINER")

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required environment variables:"
    for var in "${missing[@]}"; do
      echo "  - ${var}"
    done
    echo ""
    echo "Set them in .env or export them before running this script."
    echo "See .env.example for reference."
    exit 1
  fi
}

# ──────────────────────────────────────────────
# CHECK PREREQUISITES
# ──────────────────────────────────────────────
check_prerequisites() {
  log_info "Checking prerequisites..."

  # Check Terraform is installed
  if ! command -v terraform &>/dev/null; then
    log_error "Terraform is not installed. Please install version >= ${TF_VERSION}"
    exit 1
  fi

  local tf_ver
  tf_ver=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
  log_info "Terraform version: ${tf_ver}"

  # Check Azure CLI is installed
  if ! command -v az &>/dev/null; then
    log_error "Azure CLI (az) is not installed."
    exit 1
  fi

  log_success "Prerequisites satisfied"
}

# ──────────────────────────────────────────────
# AZURE LOGIN
# ──────────────────────────────────────────────
azure_login() {
  log_info "Authenticating to Azure..."

  # Check if already logged in
  if az account show &>/dev/null; then
    local current_sub
    current_sub=$(az account show --query id -o tsv)
    if [[ "${current_sub}" == "${ARM_SUBSCRIPTION_ID}" ]]; then
      log_success "Already logged in to subscription ${ARM_SUBSCRIPTION_ID}"
      return
    fi
  fi

  # Login using service principal with OIDC (for CI) or interactive (for local)
  if [[ -n "${ARM_CLIENT_SECRET:-}" ]]; then
    log_info "Logging in with service principal (client secret)"
    az login --service-principal \
      -u "${ARM_CLIENT_ID}" \
      -p "${ARM_CLIENT_SECRET}" \
      --tenant "${ARM_TENANT_ID}" \
      --output none
  elif [[ "${ARM_USE_OIDC:-false}" == "true" ]] && [[ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]]; then
    log_info "Logging in with OIDC (GitHub Actions)"
    az login --federated-token "$(curl -sS \
      -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
      "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
      | jq -r '.value')" \
      --service-principal \
      -u "${ARM_CLIENT_ID}" \
      --tenant "${ARM_TENANT_ID}" \
      --output none
  else
    log_info "Logging in interactively (browser)"
    az login --tenant "${ARM_TENANT_ID}" --output none
  fi

  az account set --subscription "${ARM_SUBSCRIPTION_ID}"
  log_success "Logged in to subscription ${ARM_SUBSCRIPTION_ID}"
}

# ──────────────────────────────────────────────
# CONFIGURE GIT FOR MODULE ACCESS
# ──────────────────────────────────────────────
configure_git() {
  log_info "Configuring git for module access (HTTPS instead of SSH)..."
  git config --global url."https://github.com/".insteadOf "git@github.com:"

  # For private module repos, uncomment and set MODULE_REPO_PAT:
  # git config --global url."https://x-access-token:${MODULE_REPO_PAT}@github.com/".insteadOf "git@github.com:"

  log_success "Git configured"
}

# ──────────────────────────────────────────────
# TERRAFORM INIT
# ──────────────────────────────────────────────
terraform_init() {
  log_info "Running terraform init (environment: ${ENVIRONMENT})..."

  terraform -chdir="${WORKING_DIR}" init \
    -backend-config="resource_group_name=${BACKEND_RESOURCE_GROUP}" \
    -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT}" \
    -backend-config="container_name=${BACKEND_CONTAINER}" \
    -backend-config="key=uksouth/managed-redis/${ENVIRONMENT}/terraform.tfstate" \
    -backend-config="use_oidc=true" \
    -backend-config="subscription_id=${ARM_SUBSCRIPTION_ID}" \
    -backend-config="tenant_id=${ARM_TENANT_ID}"

  log_success "Terraform initialised"
}

# ──────────────────────────────────────────────
# TERRAFORM FORMAT CHECK
# ──────────────────────────────────────────────
terraform_fmt() {
  log_info "Checking Terraform formatting..."

  if terraform -chdir="${WORKING_DIR}" fmt -check -recursive; then
    log_success "Formatting OK"
  else
    log_warn "Formatting issues found. Run 'terraform fmt -recursive' to fix."
  fi
}

# ──────────────────────────────────────────────
# TERRAFORM VALIDATE
# ──────────────────────────────────────────────
terraform_validate() {
  log_info "Validating Terraform configuration..."
  terraform -chdir="${WORKING_DIR}" validate
  log_success "Validation passed"
}

# ──────────────────────────────────────────────
# TERRAFORM PLAN
# ──────────────────────────────────────────────
terraform_plan() {
  log_info "Running terraform plan (environment: ${ENVIRONMENT})..."

  terraform -chdir="${WORKING_DIR}" plan \
    -var-file="${ENVIRONMENTS_DIR}/${ENVIRONMENT}.tfvars" \
    -out=tfplan \
    -input=false

  log_success "Plan complete. Review the output above."
}

# ──────────────────────────────────────────────
# TERRAFORM APPLY
# ──────────────────────────────────────────────
terraform_apply() {
  log_warn "About to apply changes to '${ENVIRONMENT}' environment."

  # Safety: require confirmation unless AUTO_APPROVE is set
  if [[ "${AUTO_APPROVE:-false}" != "true" ]]; then
    echo ""
    read -rp "Type 'yes' to confirm apply: " confirm
    if [[ "${confirm}" != "yes" ]]; then
      log_error "Apply cancelled."
      exit 1
    fi
  fi

  # Run plan first to generate the plan file
  terraform_plan

  log_info "Applying terraform plan..."
  terraform -chdir="${WORKING_DIR}" apply -auto-approve -input=false tfplan
  log_success "Apply complete."
}

# ──────────────────────────────────────────────
# TERRAFORM DESTROY
# ──────────────────────────────────────────────
terraform_destroy() {
  log_warn "About to DESTROY all resources in '${ENVIRONMENT}' environment!"

  # Safety: always require confirmation for destroy
  echo ""
  read -rp "Type 'destroy ${ENVIRONMENT}' to confirm: " confirm
  if [[ "${confirm}" != "destroy ${ENVIRONMENT}" ]]; then
    log_error "Destroy cancelled."
    exit 1
  fi

  log_info "Destroying infrastructure..."
  terraform -chdir="${WORKING_DIR}" destroy \
    -var-file="${ENVIRONMENTS_DIR}/${ENVIRONMENT}.tfvars" \
    -auto-approve \
    -input=false

  log_success "Destroy complete."
}

# ──────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────
main() {
  echo ""
  echo "============================================"
  echo " Terraform Managed Redis"
  echo " Action:      ${ACTION}"
  echo " Environment: ${ENVIRONMENT}"
  echo "============================================"
  echo ""

  validate_inputs
  check_prerequisites
  azure_login
  configure_git
  terraform_init
  terraform_fmt
  terraform_validate

  case "${ACTION}" in
    plan)    terraform_plan    ;;
    apply)   terraform_apply   ;;
    destroy) terraform_destroy ;;
  esac

  echo ""
  log_success "Done."
}

main "$@"
