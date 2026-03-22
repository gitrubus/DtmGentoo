#!/usr/bin/env bash
# package removal for Gentoo Linux (Dusky Remix)
# Supports Portage (emerge) and Overlay packages.
# System: Gentoo / UWSM / Hyprland
# Requires: Bash 5.0+, portage-utils (qlist), sudo
# -----------------------------------------------------------------------------

set -euo pipefail
IFS=$' \t\n'

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Gentoo Package Atoms (Category/Name)
# Note: Gentoo usually requires the category (e.g., gui-wm/hyprland)
readonly -a TARGETS=(
  gui-libs/xdg-desktop-portal-hyprland
  gui-apps/wofi
  kde-plasma/polkit-kde-agent
  sys-power/power-profiles-daemon
  x11-themes/fluent-icon-theme
  gui-apps/waybar
)

# ==============================================================================
# CONSTANTS & STYLING
# ==============================================================================

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_VERSION="1.0.0-gentoo"

if [[ -t 1 && -t 2 ]]; then
    readonly BOLD=$'\e[1m' GREEN=$'\e[32m' YELLOW=$'\e[33m' RED=$'\e[31m' BLUE=$'\e[34m' CYAN=$'\e[36m' RESET=$'\e[0m'
else
    readonly BOLD='' GREEN='' YELLOW='' RED='' BLUE='' CYAN='' RESET=''
fi

log_info() { printf '%s[INFO]%s  %s\n' "${BLUE}${BOLD}" "${RESET}" "${1:-}"; }
log_ok()   { printf '%s[OK]%s    %s\n' "${GREEN}${BOLD}" "${RESET}" "${1:-}"; }
log_warn() { printf '%s[WARN]%s  %s\n' "${YELLOW}${BOLD}" "${RESET}" "${1:-}" >&2; }
log_err()  { printf '%s[ERROR]%s %s\n' "${RED}${BOLD}" "${RESET}" "${1:-}" >&2; }

die() { log_err "${1:-Unknown error}"; exit "${2:-1}"; }

# ==============================================================================
# ENVIRONMENT VALIDATION
# ==============================================================================

check_environment() {
    [[ ${BASH_VERSINFO[0]} -lt 5 ]] && die "Bash 5.0+ required."
    (( EUID == 0 )) && die "Do NOT run as root."
    
    # Gentoo specific check: portage-utils provides 'qlist' for fast queries
    if ! command -v qlist &>/dev/null; then
        log_warn "portage-utils not found. Attempting to use emerge search (slower)..."
    fi
}

# ==============================================================================
# PACKAGE LOGIC
# ==============================================================================

# Checks if a package is actually installed in Gentoo
is_installed() {
    local pkg="$1"
    # qlist -I matches installed packages efficiently
    qlist -I "$pkg" &>/dev/null
}

# Gentoo's 'emerge --depclean' is safer than Arch's -Rns. 
# We use --unmerge (C) for explicit removal of the targets.
process_removal() {
    local -a installed_targets=()
    local pkg

    log_info "Scanning for installed Dusky components..."

    for pkg in "${TARGETS[@]}"; do
        if is_installed "$pkg"; then
            installed_targets+=("$pkg")
        else
            log_info "Skipping '${CYAN}${pkg}${RESET}': not installed."
        fi
    done

    if (( ${#installed_targets[@]} == 0 )); then
        log_ok "No configured packages found on system."
        return 0
    fi

    log_warn "Preparing to unmerge: ${BOLD}${#installed_targets[@]}${RESET} packages."
    printf '          %s%s%s\n' "${CYAN}" "${installed_targets[*]}" "${RESET}"

    # Gentoo unmerge command
    # -C / --unmerge: Removes the package
    # --ask: Gentoo's safety prompt (replaced by --confirm if auto is off)
    if sudo emerge --unmerge "${installed_targets[@]}"; then
        log_ok "Packages unmerged successfully."
        log_info "Running depclean to remove orphaned dependencies..."
        sudo emerge --depclean
    else
        die "Emerge failed during unmerge process."
    fi
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    check_environment
    process_removal
    log_ok "Gentoo cleanup complete."
}

main "$@"
