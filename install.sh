#!/usr/bin/env bash
set -euo pipefail

GUM_VERSION="${GUM_VERSION:-0.13.0}"
GUM_DOWNLOAD_BASE="${GUM_DOWNLOAD_BASE:-https://github.com/charmbracelet/gum/releases/download}"
GUM_BIN=""
GUM_TMP_DIR=""
GUM_PLATFORM=""

MIN_MACOS_VERSION="${MIN_MACOS_VERSION:-13.0}"
HOST_VERSION=""
HOST_ARCH=""
BREW_PREFIX=""
BREW_INSTALLED=0
SUDO_KEEPALIVE_PID=""
CRM114_USER="${CRM114_USER:-crm114}"
CRM114_HIDDEN_HOME="${CRM114_HIDDEN_HOME:-/Users/.crm114}"
CRM114_MIN_UID="${CRM114_MIN_UID:-550}"
CRM114_CREDENTIAL_STORE="${CRM114_CREDENTIAL_STORE:-/var/root/.crm114_credentials}"
CRM114_LIBEXEC_DIR="${CRM114_LIBEXEC_DIR:-/usr/local/libexec/crm114}"
CRM114_WISH_LOGIN="${CRM114_WISH_LOGIN:-${CRM114_LIBEXEC_DIR}/wish-login}"
CRM114_LOCAL_SSH_DIR="${CRM114_LOCAL_SSH_DIR:-${HOME}/.ssh}"
CRM114_LOCAL_KEY_PATH="${CRM114_LOCAL_KEY_PATH:-${CRM114_LOCAL_SSH_DIR}/crm114_ed25519}"
CRM114_LOCAL_KEY_COMMENT="${CRM114_LOCAL_KEY_COMMENT:-CRM114 Fantasy Workstation}"
CRM114_LOCAL_SSH_CONFIG="${CRM114_LOCAL_SSH_CONFIG:-${CRM114_LOCAL_SSH_DIR}/config}"
CRM114_LOCAL_SSH_CONFIG_BACKUP=""
EXISTING_INSTALL_ARTIFACTS=()
REINSTALL_DECISION=""

stop_sudo_keepalive() {
  if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
    kill "${SUDO_KEEPALIVE_PID}" >/dev/null 2>&1 || true
    wait "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
    SUDO_KEEPALIVE_PID=""
  fi
}

cleanup() {
  stop_sudo_keepalive
  if [ -n "${GUM_TMP_DIR:-}" ] && [ -d "${GUM_TMP_DIR:-}" ]; then
    rm -rf "${GUM_TMP_DIR}"
  fi
}

trap cleanup EXIT

log_plain() {
  printf '[crm114] %s\n' "$*" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_plain "Missing required command: $1"
    exit 1
  fi
}

version_ge() {
  local v1=( ${1//./ } )
  local v2=( ${2//./ } )
  local i

  for ((i=${#v1[@]}; i<3; i++)); do v1[i]=0; done
  for ((i=${#v2[@]}; i<3; i++)); do v2[i]=0; done

  for ((i=0; i<3; i++)); do
    if ((10#${v1[i]} > 10#${v2[i]})); then
      return 0
    elif ((10#${v1[i]} < 10#${v2[i]})); then
      return 1
    fi
  done
  return 0
}

detect_platform() {
  local os arch
  case "$(uname -s)" in
    Darwin) os="Darwin" ;;
    Linux) os="Linux" ;;
    *)
      log_plain "Unsupported operating system: $(uname -s)"
      exit 1
      ;;
  esac

  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64) arch="x86_64" ;;
    *)
      log_plain "Unsupported CPU architecture: $(uname -m)"
      exit 1
      ;;
  esac

  GUM_PLATFORM="${os}_${arch}"
}

ensure_macos_context() {
  if [ "$(uname -s)" != "Darwin" ]; then
    log_error "CRM114 installer currently supports macOS only."
    exit 1
  fi

  require_cmd sw_vers
  HOST_VERSION="$(sw_vers -productVersion)"
  if ! version_ge "${HOST_VERSION}" "${MIN_MACOS_VERSION}"; then
    log_error "macOS ${MIN_MACOS_VERSION}+ required (detected ${HOST_VERSION})."
    exit 1
  fi
}

detect_host_arch() {
  case "$(uname -m)" in
    arm64|aarch64) HOST_ARCH="arm64" ;;
    x86_64|amd64) HOST_ARCH="x86_64" ;;
    *)
      log_error "Unsupported CPU architecture: $(uname -m)"
      exit 1
      ;;
  esac
}

detect_brew_prefix() {
  if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
    BREW_INSTALLED=1
  else
    BREW_INSTALLED=0
    if [ "${HOST_ARCH}" = "arm64" ]; then
      BREW_PREFIX="/opt/homebrew"
    else
      BREW_PREFIX="/usr/local"
    fi
  fi
}

download_temp_gum() {
  detect_platform
  require_cmd curl
  require_cmd tar

  GUM_TMP_DIR="$(mktemp -d)"
  local tarball="${GUM_TMP_DIR}/gum.tar.gz"
  local url="${GUM_DOWNLOAD_BASE}/v${GUM_VERSION}/gum_${GUM_VERSION}_${GUM_PLATFORM}.tar.gz"

  log_plain "Downloading Gum ${GUM_VERSION} (${GUM_PLATFORM})"
  curl -fsSL "$url" -o "$tarball"
  tar -xzf "$tarball" -C "$GUM_TMP_DIR"

  local candidate="${GUM_TMP_DIR}/gum"
  if [[ ! -f "$candidate" ]]; then
    log_plain "Failed to extract Gum binary from archive"
    exit 1
  fi

  chmod +x "$candidate"
  GUM_BIN="$candidate"
}

ensure_gum() {
  if command -v gum >/dev/null 2>&1; then
    GUM_BIN="$(command -v gum)"
    return
  fi

  log_plain "Gum not found on PATH; fetching temporary copy..."
  download_temp_gum
}

start_sudo_keepalive() {
  require_cmd sudo
  log_info "macOS will prompt for your administrator password in this terminal window; type it and press Enter to continue."
  sudo -v
  log_info "Sudo privileges secured; keeping the session alive for the rest of the installer."
  (
    while true; do
      sudo -n true >/dev/null 2>&1 || exit
      sleep 45
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
}

next_available_uid() {
  local used_uids uid
  used_uids="$(dscl . -list /Users UniqueID 2>/dev/null | awk '{print $2}' | tr '\n' ' ')"
  if [ -z "$used_uids" ]; then
    log_error "Unable to determine existing user IDs"
    exit 1
  fi
  uid="$CRM114_MIN_UID"
  while printf '%s\n' $used_uids | grep -qx "$uid"; do
    uid=$((uid + 1))
  done
  printf '%s' "$uid"
}

create_hidden_home() {
  if [ -d "${CRM114_HIDDEN_HOME}" ]; then
    log_info "Hidden home ${CRM114_HIDDEN_HOME} already exists; ensuring permissions."
    sudo chmod 700 "${CRM114_HIDDEN_HOME}"
    sudo chflags hidden "${CRM114_HIDDEN_HOME}"
    return
  fi

  log_info "Creating hidden home directory at ${CRM114_HIDDEN_HOME}."
  sudo install -d -m 700 "${CRM114_HIDDEN_HOME}"
  sudo chflags hidden "${CRM114_HIDDEN_HOME}"
}

ensure_hidden_home_permissions() {
  if [ ! -d "${CRM114_HIDDEN_HOME}" ]; then
    log_warn "Hidden home ${CRM114_HIDDEN_HOME} missing when enforcing ownership."
    return
  fi
  log_info "Assigning ${CRM114_HIDDEN_HOME} to ${CRM114_USER}:staff."
  sudo chown "${CRM114_USER}:staff" "${CRM114_HIDDEN_HOME}"
  sudo chmod 700 "${CRM114_HIDDEN_HOME}"
  sudo chflags hidden "${CRM114_HIDDEN_HOME}"
}

ensure_hidden_user() {
  if id "${CRM114_USER}" >/dev/null 2>&1; then
    log_info "User ${CRM114_USER} already exists; ensuring attributes are correct."
  else
    uid="$(next_available_uid)"
    log_info "Creating hidden user ${CRM114_USER} (uid ${uid})."
    sudo dscl . -create "/Users/${CRM114_USER}"
    sudo dscl . -create "/Users/${CRM114_USER}" UniqueID "$uid"
    sudo dscl . -create "/Users/${CRM114_USER}" PrimaryGroupID 20
    sudo dscl . -create "/Users/${CRM114_USER}" UserShell /bin/zsh
    sudo dscl . -create "/Users/${CRM114_USER}" NFSHomeDirectory "${CRM114_HIDDEN_HOME}"
    sudo dscl . -create "/Users/${CRM114_USER}" RealName "CRM114 Workstation"
  fi

  sudo dscl . -create "/Users/${CRM114_USER}" IsHidden 1
  sudo dscl . -create "/Users/${CRM114_USER}" NFSHomeDirectory "${CRM114_HIDDEN_HOME}"
  sudo dscl . -create "/Users/${CRM114_USER}" UserShell /bin/zsh
  sudo chflags hidden "${CRM114_HIDDEN_HOME}"
}

set_random_password() {
  if [[ -f "${CRM114_CREDENTIAL_STORE}" ]]; then
    log_info "Credential store ${CRM114_CREDENTIAL_STORE} already exists; retaining existing password."
    return
  fi

  require_cmd tr
  require_cmd head

  local password
  password="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
  printf '%s:%s\n' "${CRM114_USER}" "$password" | sudo tee "${CRM114_CREDENTIAL_STORE}" >/dev/null
  sudo chmod 600 "${CRM114_CREDENTIAL_STORE}"
  sudo chown root:wheel "${CRM114_CREDENTIAL_STORE}"
  log_info "Stored generated password at ${CRM114_CREDENTIAL_STORE}."
  sudo dscl . -passwd "/Users/${CRM114_USER}" "$password"
}

generate_local_keypair() {
  require_cmd ssh-keygen
  log_info "Ensuring dedicated SSH key at ${CRM114_LOCAL_KEY_PATH}."
  mkdir -p "${CRM114_LOCAL_SSH_DIR}"
  if [[ -f "${CRM114_LOCAL_KEY_PATH}" ]]; then
    mv "${CRM114_LOCAL_KEY_PATH}" "${CRM114_LOCAL_KEY_PATH}.bak.$(date +%s)"
  fi
  if [[ -f "${CRM114_LOCAL_KEY_PATH}.pub" ]]; then
    mv "${CRM114_LOCAL_KEY_PATH}.pub" "${CRM114_LOCAL_KEY_PATH}.pub.bak.$(date +%s)"
  fi
  ssh-keygen -t ed25519 -f "${CRM114_LOCAL_KEY_PATH}" -N "" -C "${CRM114_LOCAL_KEY_COMMENT}" >/dev/null
}

install_remote_authorized_key() {
  local remote_ssh_dir="${CRM114_HIDDEN_HOME}/.ssh"
  local remote_authorized_keys="${remote_ssh_dir}/authorized_keys"
  log_info "Installing authorized_keys for ${CRM114_USER}."
  sudo install -d -m 700 -o "${CRM114_USER}" -g staff "${remote_ssh_dir}"
  sudo install -m 600 -o "${CRM114_USER}" -g staff /dev/null "${remote_authorized_keys}"
  sudo tee "${remote_authorized_keys}" >/dev/null <"${CRM114_LOCAL_KEY_PATH}.pub"
}

record_existing_artifact() {
  local path="$1"
  if [[ -e "$path" ]]; then
    EXISTING_INSTALL_ARTIFACTS+=("$path")
  fi
}

list_existing_artifacts() {
  if [[ ${#EXISTING_INSTALL_ARTIFACTS[@]} -eq 0 ]]; then
    printf 'none\n'
    return
  fi
  printf '%s\n' "${EXISTING_INSTALL_ARTIFACTS[@]}"
}

detect_existing_crm114_state() {
  EXISTING_INSTALL_ARTIFACTS=()
  record_existing_artifact "${CRM114_HIDDEN_HOME}"
  record_existing_artifact "${CRM114_CREDENTIAL_STORE}"
  record_existing_artifact "${CRM114_LIBEXEC_DIR}"
  record_existing_artifact "${CRM114_WISH_LOGIN}"
  if ls /etc/ssh/sshd_config.crm114.bak.* >/dev/null 2>&1; then
    EXISTING_INSTALL_ARTIFACTS+=("/etc/ssh/sshd_config.crm114.bak.*")
  fi
  if [[ -f "${CRM114_LOCAL_KEY_PATH}" ]]; then
    EXISTING_INSTALL_ARTIFACTS+=("${CRM114_LOCAL_KEY_PATH}")
  fi
  if [[ -f "${CRM114_LOCAL_KEY_PATH}.pub" ]]; then
    EXISTING_INSTALL_ARTIFACTS+=("${CRM114_LOCAL_KEY_PATH}.pub")
  fi
  if [[ -f "${CRM114_LOCAL_SSH_CONFIG}" ]]; then
    EXISTING_INSTALL_ARTIFACTS+=("${CRM114_LOCAL_SSH_CONFIG}")
  fi
}

remove_local_ssh_rules() {
  if [[ ! -f "${CRM114_LOCAL_SSH_CONFIG}" ]] || [[ ! -s "${CRM114_LOCAL_SSH_CONFIG}" ]]; then
    return
  fi

  local cleaned
  cleaned="$(mktemp)"
  awk -v user="${CRM114_USER}" '
    function is_match_block(line) {
      return line ~ "^Match" && line ~ "Host[[:space:]]+localhost" && line ~ "User[[:space:]]+" user
    }
    function is_host_block(line) {
      return line ~ "^Host[[:space:]]+crm114([[:space:]]|$)"
    }
    {
      if (skip && $0 ~ "^[[:space:]]*$") {
        skip = 0
        next
      }
      if (skip && ($0 ~ "^Match[[:space:]]" || $0 ~ "^Host[[:space:]]")) {
        if (is_match_block($0) || is_host_block($0)) {
          skip = 1
          next
        }
        skip = 0
      }
      if (skip) {
        next
      }
      if (is_match_block($0) || is_host_block($0)) {
        skip = 1
        next
      }
      print
    }
  ' "${CRM114_LOCAL_SSH_CONFIG}" >"${cleaned}"
  mv "${cleaned}" "${CRM114_LOCAL_SSH_CONFIG}"
}

install_local_ssh_rules() {
  log_info "Configuring local SSH alias and Match rules for crm114@localhost."
  mkdir -p "${CRM114_LOCAL_SSH_DIR}"
  if [[ -f "${CRM114_LOCAL_SSH_CONFIG}" ]]; then
    CRM114_LOCAL_SSH_CONFIG_BACKUP="${CRM114_LOCAL_SSH_CONFIG}.crm114.bak.$(date +%s)"
    cp "${CRM114_LOCAL_SSH_CONFIG}" "${CRM114_LOCAL_SSH_CONFIG_BACKUP}"
  else
    touch "${CRM114_LOCAL_SSH_CONFIG}"
  fi

  remove_local_ssh_rules

  cat >>"${CRM114_LOCAL_SSH_CONFIG}" <<EOF
Host crm114
    HostName localhost
    User ${CRM114_USER}
    IdentityFile ${CRM114_LOCAL_KEY_PATH}
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Match User ${CRM114_USER} Host localhost
    IdentityFile ${CRM114_LOCAL_KEY_PATH}
    IdentitiesOnly yes
EOF

  chmod 600 "${CRM114_LOCAL_SSH_CONFIG}"
}

enforce_hidden_user_properties() {
  sudo dscl . -create "/Users/${CRM114_USER}" IsHidden 1
  sudo dscl . -create "/Users/${CRM114_USER}" NFSHomeDirectory "${CRM114_HIDDEN_HOME}"
  sudo dscl . -create "/Users/${CRM114_USER}" UserShell /bin/zsh
  sudo chflags hidden "${CRM114_HIDDEN_HOME}"
}

provision_hidden_user() {
  create_hidden_home
  ensure_hidden_user
  enforce_hidden_user_properties
  ensure_hidden_home_permissions
  set_random_password
  log_info "Hidden user ${CRM114_USER} is provisioned and hidden."
}

ensure_remote_login_enabled() {
  log_info "Enabling Remote Login (SSH) in macOS." 
  sudo systemsetup -setremotelogin on >/dev/null
}

restrict_access_group() {
  log_info "Restricting SSH access to ${CRM114_USER}."
  sudo dseditgroup -o edit -a "${CRM114_USER}" -t user com.apple.access_ssh >/dev/null
}

goingup_libexec() {
  log_info "Ensuring ${CRM114_LIBEXEC_DIR} exists."
  sudo install -d -m 755 "${CRM114_LIBEXEC_DIR}"
  sudo chown root:wheel "${CRM114_LIBEXEC_DIR}"
}

goingup_placeholder_wish_login() {
  log_info "Ensuring placeholder ForceCommand target at ${CRM114_WISH_LOGIN}."
  goingup_libexec
  sudo tee "${CRM114_WISH_LOGIN}" >/dev/null <<EOF
#!/bin/zsh
export CRM114_HOME="${CRM114_HIDDEN_HOME}"
cd "${CRM114_HIDDEN_HOME}" || exit 1
exec /bin/zsh -l
EOF
  sudo chmod 755 "${CRM114_WISH_LOGIN}"
  sudo chown root:wheel "${CRM114_WISH_LOGIN}"
}

backup_sshd_config() {
  local timestamp
  timestamp="$(date +%s)"
  SSH_CONFIG_BACKUP="/etc/ssh/sshd_config.crm114.bak.${timestamp}"
  log_info "Backing up /etc/ssh/sshd_config to ${SSH_CONFIG_BACKUP}."
  sudo cp /etc/ssh/sshd_config "${SSH_CONFIG_BACKUP}"
}

apply_sshd_hardening() {
  log_info "Applying sshd hardening for CRM114."
  sudo tee /etc/ssh/sshd_config >/dev/null <<EOF
# CRM114 sshd hardening
ListenAddress 127.0.0.1
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes

Match User ${CRM114_USER}
    AllowTcpForwarding no
    X11Forwarding no
    ForceCommand ${CRM114_WISH_LOGIN}
    PermitPTY yes
    PermitTunnel no
    AuthenticationMethods publickey
EOF
}

validate_and_restart_sshd() {
  log_info "Validating sshd configuration."
  sudo sshd -t
  log_info "Restarting sshd service."
  sudo launchctl kickstart -k system/com.openssh.sshd
}

summarize_hidden_user_state() {
  log_info "Hidden user summary:"
  log_info "  • Account: ${CRM114_USER}"
  log_info "  • Home: ${CRM114_HIDDEN_HOME}"
  log_info "  • Cred store: ${CRM114_CREDENTIAL_STORE}"
}

format_summary_row() {
  local item="$1"
  local status="$2"
  local details="$3"
  printf "%s\t%s\t%s\n" "$item" "$status" "$details"
}

summary_hidden_user_row() {
  if id "${CRM114_USER}" >/dev/null 2>&1; then
    local owner
    owner="$(sudo stat -f '%Su:%Sg' "${CRM114_HIDDEN_HOME}" 2>/dev/null || echo "unknown")"
    format_summary_row "Hidden user" "✅" "uid $(id -u "${CRM114_USER}") home owner ${owner}"
    return
  fi
  format_summary_row "Hidden user" "⚠️" "missing ${CRM114_USER}"
}

summary_credential_store_row() {
  if sudo test -f "${CRM114_CREDENTIAL_STORE}"; then
    format_summary_row "Credential store" "✅" "${CRM114_CREDENTIAL_STORE}"
  else
    format_summary_row "Credential store" "⚠️" "missing credential store"
  fi
}

summary_remote_login_row() {
  if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
    format_summary_row "Remote Login" "✅" "Remote Login enabled"
  else
    format_summary_row "Remote Login" "⚠️" "Remote Login disabled"
  fi
}

summary_local_keypair_row() {
  if [[ -f "${CRM114_LOCAL_KEY_PATH}" && -f "${CRM114_LOCAL_KEY_PATH}.pub" ]]; then
    local fingerprint
    fingerprint=""
    if command -v ssh-keygen >/dev/null 2>&1; then
      fingerprint="$(ssh-keygen -lf "${CRM114_LOCAL_KEY_PATH}.pub" 2>/dev/null | awk '{print $2}')"
    fi
    if [[ -n "${fingerprint}" ]]; then
      format_summary_row "Local keypair" "✅" "${CRM114_LOCAL_KEY_PATH} ${fingerprint}"
    else
      format_summary_row "Local keypair" "✅" "${CRM114_LOCAL_KEY_PATH}"
    fi
    return
  fi
  format_summary_row "Local keypair" "⚠️" "missing ${CRM114_LOCAL_KEY_PATH}"
}

summary_local_ssh_config_row() {
  if [[ -f "${CRM114_LOCAL_SSH_CONFIG}" ]]; then
    if grep -Eq "^Host[[:space:]]+crm114([[:space:]]|$)" "${CRM114_LOCAL_SSH_CONFIG}" && \
       grep -Eq "^Match[[:space:]]+User[[:space:]]+${CRM114_USER}[[:space:]]+Host[[:space:]]+localhost" "${CRM114_LOCAL_SSH_CONFIG}"; then
      format_summary_row "Local SSH config" "✅" "Host crm114 + Match rules present"
      return
    fi
    format_summary_row "Local SSH config" "⚠️" "missing Host or Match rules"
    return
  fi
  format_summary_row "Local SSH config" "⚠️" "missing ${CRM114_LOCAL_SSH_CONFIG}"
}

summary_remote_authorized_key_row() {
  local remote_authorized_keys="${CRM114_HIDDEN_HOME}/.ssh/authorized_keys"
  if sudo test -f "${remote_authorized_keys}"; then
    local local_pub
    local_pub=""
    if [[ -f "${CRM114_LOCAL_KEY_PATH}.pub" ]]; then
      local_pub="$(cat "${CRM114_LOCAL_KEY_PATH}.pub")"
    fi
    if [[ -n "${local_pub}" ]] && sudo grep -qxF "${local_pub}" "${remote_authorized_keys}" >/dev/null 2>&1; then
      format_summary_row "Remote authorized key" "✅" "authorized_keys synced"
      return
    fi
    format_summary_row "Remote authorized key" "⚠️" "missing matching key"
    return
  fi
  format_summary_row "Remote authorized key" "⚠️" "authorized_keys missing"
}

show_completion_summary() {
  local rows=()
  rows+=("$(summary_hidden_user_row)")
  rows+=("$(summary_credential_store_row)")
  rows+=("$(summary_remote_login_row)")
  rows+=("$(summary_local_keypair_row)")
  rows+=("$(summary_local_ssh_config_row)")
  rows+=("$(summary_remote_authorized_key_row)")
  local data
  data="Item\tStatus\tDetails\n$(printf "%s\n" "${rows[@]}")"
  if gum_available; then
    printf "%b" "${data}" | "${GUM_BIN}" table --columns "Item" "Status" "Details"
  else
    printf "%b" "${data}"
  fi
}

gum_available() {
  [[ -n ${GUM_BIN:-} ]] && [[ -x ${GUM_BIN:-} ]]
}

log_info() {
  if gum_available; then
    "$GUM_BIN" log --level info "$*"
  else
    log_plain "$*"
  fi
}

log_warn() {
  if gum_available; then
    "$GUM_BIN" log --level warn "$*"
  else
    log_plain "WARN: $*"
  fi
}

log_error() {
  if gum_available; then
    "$GUM_BIN" log --level error "$*"
  else
    log_plain "ERROR: $*"
  fi
}


show_intro_banner() {
  local message
  message="CRM114 Fantasy Workstation Installer\n\n";
  message+="This script will (eventually):\n"
  message+="  • Prepare sudo privileges and macOS prerequisites\n"
  message+="  • Create the hidden crm114 user home at /Users/.crm114\n"
  message+="  • Lock sshd to localhost with key-only authentication\n"
  message+="  • Install Charm stack binaries and Wish login shell\n"

  if gum_available; then
    printf "%s\n" "$message" | "$GUM_BIN" style --border double --margin "1 2"
  else
    printf "%s\n" "$message"
  fi
}

require_confirmation() {
  if gum_available; then
    if "$GUM_BIN" confirm --default=false "Proceed with the CRM114 installer bootstrap?"; then
      return 0
    fi
    return 1
  fi

  read -r -p "Proceed with the CRM114 installer bootstrap? [y/N] " reply
  case "$reply" in
    y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

preflight_checks() {
  ensure_macos_context
  detect_host_arch
  detect_brew_prefix
}

log_environment_summary() {
  log_info "Host macOS ${HOST_VERSION} (${HOST_ARCH}); minimum required ${MIN_MACOS_VERSION}."
  if [[ ${BREW_INSTALLED} -eq 1 ]]; then
    log_info "Homebrew detected at ${BREW_PREFIX}."
  else
    log_warn "Homebrew not found; will install under ${BREW_PREFIX} later in this script."
  fi
}

run_hidden_user_work() {
  log_info "Provisioning hidden crm114 user and home."
  provision_hidden_user
  summarize_hidden_user_state
}

run_ssh_ready_state() {
  log_info "Configuring SSH daemon for CRM114."
  ensure_remote_login_enabled
  restrict_access_group
  goingup_placeholder_wish_login
  backup_sshd_config
  apply_sshd_hardening
  validate_and_restart_sshd
  generate_local_keypair
  install_remote_authorized_key
  install_local_ssh_rules
}

prompt_reinstall_cleanup() {
  if gum_available; then
    "$GUM_BIN" log --level warn "Existing CRM114 installation artifacts detected:"
    list_existing_artifacts | "$GUM_BIN" style --border normal --margin "1 2"
    if ! "$GUM_BIN" confirm --default=false "Remove previous CRM114 installation?"; then
      REINSTALL_DECISION="skip"
      return
    fi
    if ! "$GUM_BIN" confirm --default=false "This will delete hidden user data. Continue?"; then
      REINSTALL_DECISION="skip"
      return
    fi
    REINSTALL_DECISION="remove"
    return
  fi

  log_warn "Existing CRM114 installation artifacts detected:"
  list_existing_artifacts
  read -r -p "Remove previous CRM114 installation? [y/N] " reply
  case "$reply" in
    y|Y)
      read -r -p "This will delete hidden user data. Continue? [y/N] " reply2
      case "$reply2" in
        y|Y) REINSTALL_DECISION="remove" ; return ;;
        *) REINSTALL_DECISION="skip" ; return ;;
      esac
      ;;
    *) REINSTALL_DECISION="skip" ; return ;;
  esac
}

remove_hidden_user() {
  if id "${CRM114_USER}" >/dev/null 2>&1; then
    log_info "Deleting user ${CRM114_USER}."
    sudo sysadminctl -deleteUser "${CRM114_USER}" -secure || sudo dscl . -delete "/Users/${CRM114_USER}"
  fi
}

remove_hidden_home() {
  if [[ -d "${CRM114_HIDDEN_HOME}" ]]; then
    log_info "Removing hidden home ${CRM114_HIDDEN_HOME}."
    sudo rm -rf "${CRM114_HIDDEN_HOME}"
  fi
}

remove_credential_store() {
  if [[ -f "${CRM114_CREDENTIAL_STORE}" ]]; then
    log_info "Removing credential store ${CRM114_CREDENTIAL_STORE}."
    sudo rm -f "${CRM114_CREDENTIAL_STORE}"
  fi
}

remove_libexec_assets() {
  if [[ -d "${CRM114_LIBEXEC_DIR}" ]]; then
    log_info "Removing libexec directory ${CRM114_LIBEXEC_DIR}."
    sudo rm -rf "${CRM114_LIBEXEC_DIR}"
  fi
}

restore_sshd_backup_if_present() {
  local latest_backup
  latest_backup="$(ls -1t /etc/ssh/sshd_config.crm114.bak.* 2>/dev/null | head -n1 || true)"
  if [[ -n "$latest_backup" ]]; then
    log_info "Restoring sshd_config from ${latest_backup}."
    sudo cp "$latest_backup" /etc/ssh/sshd_config
  fi
}

remove_local_keys_and_config() {
  if [[ -f "${CRM114_LOCAL_KEY_PATH}" ]]; then
    log_info "Removing local key ${CRM114_LOCAL_KEY_PATH}."
    rm -f "${CRM114_LOCAL_KEY_PATH}"
  fi
  if [[ -f "${CRM114_LOCAL_KEY_PATH}.pub" ]]; then
    log_info "Removing local public key ${CRM114_LOCAL_KEY_PATH}.pub."
    rm -f "${CRM114_LOCAL_KEY_PATH}.pub"
  fi
  if [[ -f "${CRM114_LOCAL_SSH_CONFIG}" ]]; then
    log_info "Removing CRM114 SSH alias from ${CRM114_LOCAL_SSH_CONFIG}."
    remove_local_ssh_rules
  fi
}

perform_reinstall_cleanup() {
  log_info "Removing previous CRM114 installation."
  remove_hidden_user
  remove_hidden_home
  remove_credential_store
  remove_libexec_assets
  restore_sshd_backup_if_present
  remove_local_keys_and_config
}

run_reinstall_detection() {
  detect_existing_crm114_state
  if [[ ${#EXISTING_INSTALL_ARTIFACTS[@]} -eq 0 ]]; then
    return
  fi

  prompt_reinstall_cleanup
  if [[ "$REINSTALL_DECISION" == "remove" ]]; then
    perform_reinstall_cleanup
  else
    log_warn "Continuing without removal; existing artifacts may conflict."
  fi
}

main() {
  ensure_gum
  show_intro_banner

  if ! require_confirmation; then
    log_warn "Installer aborted by user"
    exit 0
  fi

  run_reinstall_detection

  preflight_checks
  start_sudo_keepalive
  log_environment_summary
  run_hidden_user_work
  run_ssh_ready_state
  show_completion_summary

  log_info "Hidden user ${CRM114_USER} can now be reached via: ssh crm114@localhost"
  log_info "Next steps: install Charm stack binaries, Wish shell, and remaining workstation assets."
}

main "$@"
