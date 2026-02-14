#!/usr/bin/env bash
# Bashclaw installer - standalone script, no project dependencies
# Usage: curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
set -euo pipefail

BASHCLAW_REPO="https://github.com/shareAI-lab/bashclaw.git"
BASHCLAW_TARBALL="https://github.com/shareAI-lab/bashclaw/archive/refs/heads/main.tar.gz"

_INSTALL_DIR="${BASHCLAW_INSTALL_DIR:-${HOME}/.bashclaw/bin}"
_NO_PATH=false
_UNINSTALL=false
_PREFIX=""

# ---- Output helpers ----

_print() {
  printf '%s\n' "$*"
}

_info() {
  printf '[INFO] %s\n' "$*"
}

_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

_fatal() {
  _error "$@"
  exit 1
}

_banner() {
  cat <<'BANNER'
  _               _          _
 | |__   __ _ ___| |__   ___| | __ ___      __
 | '_ \ / _` / __| '_ \ / __| |/ _` \ \ /\ / /
 | |_) | (_| \__ \ | | | (__| | (_| |\ V  V /
 |_.__/ \__,_|___/_| |_|\___|_|\__,_| \_/\_/

 Bash-native AI agent framework
BANNER
  _print ""
}

# ---- Platform detection ----

_detect_os() {
  if [[ -d "/data/data/com.termux" ]]; then
    printf 'termux'
    return
  fi
  case "$(uname -s)" in
    Darwin) printf 'darwin' ;;
    Linux)  printf 'linux' ;;
    *)      printf 'unknown' ;;
  esac
}

_detect_distro() {
  if [[ -f /etc/os-release ]]; then
    local id
    id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    printf '%s' "$id"
  elif is_command_available lsb_release; then
    lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]'
  else
    printf 'unknown'
  fi
}

_check_bash_version() {
  local major="${BASH_VERSINFO[0]:-0}"
  local minor="${BASH_VERSINFO[1]:-0}"
  if (( major < 3 || (major == 3 && minor < 2) )); then
    _fatal "Bash 3.2+ is required. Current: ${BASH_VERSION}"
  fi
  _info "Bash version: ${BASH_VERSION}"
}

_is_command_available() {
  command -v "$1" &>/dev/null
}

# ---- Dependency checks ----

_check_curl() {
  if ! _is_command_available curl; then
    _fatal "curl is required but not found. Please install curl first."
  fi
  _info "curl: found"
}

_install_jq() {
  if _is_command_available jq; then
    _info "jq: found ($(jq --version 2>/dev/null || echo 'unknown'))"
    return 0
  fi

  _info "jq not found, attempting to install..."

  local os
  os="$(_detect_os)"

  case "$os" in
    darwin)
      if _is_command_available brew; then
        _info "Installing jq via Homebrew..."
        brew install jq
      else
        _info "Downloading jq binary..."
        _install_jq_binary "darwin"
      fi
      ;;
    linux)
      local distro
      distro="$(_detect_distro)"
      case "$distro" in
        ubuntu|debian|linuxmint|pop)
          _info "Installing jq via apt-get..."
          sudo apt-get update -qq && sudo apt-get install -y -qq jq
          ;;
        fedora|rhel|centos|rocky|alma)
          _info "Installing jq via yum..."
          sudo yum install -y jq
          ;;
        arch|manjaro)
          _info "Installing jq via pacman..."
          sudo pacman -S --noconfirm jq
          ;;
        alpine)
          _info "Installing jq via apk..."
          sudo apk add jq
          ;;
        opensuse*|sles)
          _info "Installing jq via zypper..."
          sudo zypper install -y jq
          ;;
        *)
          _info "Unknown distro, downloading jq binary..."
          _install_jq_binary "linux"
          ;;
      esac
      ;;
    termux)
      _info "Installing jq via pkg..."
      pkg install -y jq
      ;;
    *)
      _info "Downloading jq binary..."
      _install_jq_binary "linux"
      ;;
  esac

  if ! _is_command_available jq; then
    _fatal "Failed to install jq. Please install it manually."
  fi
  _info "jq: installed"
}

_install_jq_binary() {
  local platform="$1"
  local arch
  arch="$(uname -m)"
  local jq_url=""

  case "${platform}-${arch}" in
    darwin-x86_64)  jq_url="https://github.com/jqlang/jq/releases/latest/download/jq-macos-amd64" ;;
    darwin-arm64)   jq_url="https://github.com/jqlang/jq/releases/latest/download/jq-macos-arm64" ;;
    linux-x86_64)   jq_url="https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64" ;;
    linux-aarch64)  jq_url="https://github.com/jqlang/jq/releases/latest/download/jq-linux-arm64" ;;
    linux-armv7l)   jq_url="https://github.com/jqlang/jq/releases/latest/download/jq-linux-armhf" ;;
    *)
      _fatal "No pre-built jq binary for ${platform}-${arch}"
      ;;
  esac

  local jq_dir="${HOME}/.local/bin"
  mkdir -p "$jq_dir"
  curl -fsSL "$jq_url" -o "${jq_dir}/jq"
  chmod +x "${jq_dir}/jq"

  if [[ ":$PATH:" != *":${jq_dir}:"* ]]; then
    export PATH="${jq_dir}:$PATH"
  fi
}

# ---- Installation ----

_download_bashclaw() {
  local install_dir="$1"
  local parent_dir
  parent_dir="$(dirname "$install_dir")"
  mkdir -p "$parent_dir"

  if _is_command_available git; then
    _info "Cloning bashclaw..."
    if [[ -d "$install_dir" ]]; then
      _info "Existing installation found, updating..."
      (cd "$install_dir" && git pull --ff-only 2>/dev/null) || {
        _warn "Git pull failed, performing fresh clone..."
        rm -rf "$install_dir"
        git clone --depth 1 "$BASHCLAW_REPO" "$install_dir"
      }
    else
      git clone --depth 1 "$BASHCLAW_REPO" "$install_dir"
    fi
  else
    _info "Downloading bashclaw tarball..."
    local tmp_tar
    tmp_tar="$(mktemp -t bashclaw_install.XXXXXX.tar.gz 2>/dev/null || mktemp /tmp/bashclaw_install.XXXXXX.tar.gz)"
    curl -fsSL "$BASHCLAW_TARBALL" -o "$tmp_tar"
    mkdir -p "$install_dir"
    tar xzf "$tmp_tar" -C "$install_dir" --strip-components=1
    rm -f "$tmp_tar"
  fi

  chmod +x "${install_dir}/bashclaw"
  _info "Installed to: $install_dir"
}

_add_to_path() {
  local install_dir="$1"

  if [[ "$_NO_PATH" == "true" ]]; then
    _info "Skipping PATH modification (--no-path)"
    return 0
  fi

  # Check if already in PATH
  if [[ ":$PATH:" == *":${install_dir}:"* ]]; then
    _info "Already in PATH"
    return 0
  fi

  local path_line="export PATH=\"${install_dir}:\$PATH\""
  local shell_configs=()

  if [[ -f "$HOME/.bashrc" ]]; then
    shell_configs+=("$HOME/.bashrc")
  fi
  if [[ -f "$HOME/.bash_profile" ]]; then
    shell_configs+=("$HOME/.bash_profile")
  elif [[ -f "$HOME/.profile" ]]; then
    shell_configs+=("$HOME/.profile")
  fi
  if [[ -f "$HOME/.zshrc" ]]; then
    shell_configs+=("$HOME/.zshrc")
  fi

  local added=false
  local rc
  for rc in "${shell_configs[@]}"; do
    if grep -qF "bashclaw" "$rc" 2>/dev/null; then
      _info "PATH entry already in $rc"
      continue
    fi
    printf '\n# bashclaw\n%s\n' "$path_line" >> "$rc"
    _info "Added to PATH in $rc"
    added=true
  done

  if [[ "$added" == "false" && ${#shell_configs[@]} -eq 0 ]]; then
    # No shell configs found, create .bashrc
    printf '# bashclaw\n%s\n' "$path_line" >> "$HOME/.bashrc"
    _info "Added to PATH in $HOME/.bashrc"
  fi

  export PATH="${install_dir}:$PATH"
}

_create_default_config() {
  local state_dir="${HOME}/.bashclaw"
  mkdir -p "$state_dir"
  mkdir -p "$state_dir/logs"
  mkdir -p "$state_dir/sessions"
  mkdir -p "$state_dir/memory"
  mkdir -p "$state_dir/cron"
  mkdir -p "$state_dir/hooks"

  local config_file="${state_dir}/bashclaw.json"
  if [[ -f "$config_file" ]]; then
    _info "Config already exists: $config_file"
    return 0
  fi

  cat > "$config_file" <<'CONFIGEOF'
{
  "agents": {
    "defaults": {
      "model": "claude-sonnet-4-20250514",
      "maxTurns": 50,
      "contextTokens": 200000
    },
    "list": []
  },
  "channels": {},
  "gateway": {
    "port": 18789,
    "auth": {}
  },
  "session": {
    "scope": "per-sender",
    "idleResetMinutes": 30,
    "maxHistory": 200
  }
}
CONFIGEOF

  chmod 600 "$config_file"
  _info "Created default config: $config_file"
}

_uninstall() {
  _banner
  _print "Uninstalling bashclaw..."

  local install_dir="$_INSTALL_DIR"
  if [[ -d "$install_dir" ]]; then
    rm -rf "$install_dir"
    _info "Removed: $install_dir"
  fi

  # Remove PATH entries from shell configs
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
    if [[ -f "$rc" ]] && grep -qF "bashclaw" "$rc" 2>/dev/null; then
      local tmp
      tmp="$(mktemp)"
      grep -vF "bashclaw" "$rc" > "$tmp"
      mv "$tmp" "$rc"
      _info "Cleaned PATH from $rc"
    fi
  done

  _print ""
  _print "bashclaw has been uninstalled."
  _print "Your data in ~/.bashclaw has been preserved."
  _print "To remove all data: rm -rf ~/.bashclaw"
}

_print_instructions() {
  _print ""
  _print "============================================"
  _print "  Installation complete!"
  _print "============================================"
  _print ""
  _print "Getting started:"
  _print ""
  _print "  1. Set your API key:"
  _print "     export ANTHROPIC_API_KEY='your-key-here'"
  _print ""
  _print "  2. Run the setup wizard:"
  _print "     bashclaw onboard"
  _print ""
  _print "  3. Or start chatting directly:"
  _print "     bashclaw agent -i"
  _print ""
  _print "  4. Start the gateway server:"
  _print "     bashclaw gateway"
  _print ""
  _print "  5. Install as a system service:"
  _print "     bashclaw daemon install --enable"
  _print ""
  _print "For help: bashclaw help"
  _print ""
  _print "If bashclaw is not found, restart your shell or run:"
  _print "  source ~/.bashrc  # or ~/.zshrc"
  _print ""
}

# ---- Main ----

_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)
        _PREFIX="$2"
        _INSTALL_DIR="$2"
        shift 2
        ;;
      --no-path)
        _NO_PATH=true
        shift
        ;;
      --uninstall)
        _UNINSTALL=true
        shift
        ;;
      --help|-h)
        _print "bashclaw installer"
        _print ""
        _print "Usage: install.sh [options]"
        _print ""
        _print "Options:"
        _print "  --prefix DIR    Install to DIR (default: ~/.bashclaw/bin)"
        _print "  --no-path       Don't modify shell PATH"
        _print "  --uninstall     Remove bashclaw"
        _print "  --help          Show this help"
        exit 0
        ;;
      *)
        _warn "Unknown option: $1"
        shift
        ;;
    esac
  done
}

main() {
  _parse_args "$@"

  if [[ "$_UNINSTALL" == "true" ]]; then
    _uninstall
    exit 0
  fi

  _banner

  _print "Installing bashclaw..."
  _print ""

  # System checks
  _check_bash_version
  _check_curl
  _install_jq
  _print ""

  # Download and install
  _download_bashclaw "$_INSTALL_DIR"
  _add_to_path "$_INSTALL_DIR"
  _create_default_config

  _print_instructions
}

main "$@"
