#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}::${NC} $*"; }
success() { echo -e "${GREEN}✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}!${NC}  $*"; }
die()     { echo -e "${RED}✗${NC}  $*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || die "This script is for Arch Linux only."
command -v yay &>/dev/null         || die "yay not found."

echo -e "\n${BOLD}Hyprland Dotfiles Uninstaller${NC}\n"
warn "This will remove installed packages and config files."
read -rp "$(echo -e "${YELLOW}?${NC}  Continue? [y/N] ")" ans
[[ "${ans,,}" == "y" ]] || { info "Aborted."; exit 0; }

# ── packages ──────────────────────────────────────────────────────────────────
remove_packages() {
  local -a pkgs=(
    hyprland waybar rofi-wayland kitty
    zsh oh-my-zsh-git zsh-autosuggestions
    fastfetch btop cava yazi
    swappy grim slurp wl-clipboard
    swaync udiskie network-manager-applet
    networkmanager bluez bluez-utils
    pipewire wireplumber pipewire-pulse pavucontrol brightnessctl
    neovim tmux obs-studio nwg-look
    ttf-fira-code nerd-fonts-fira-code
    xdg-desktop-portal-hyprland xdg-user-dirs
    awww
  )

  local -a optional_pkgs=(spotify spicetify-cli)
  local -a sddm_pkgs=(sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg)

  local -a to_remove=()
  for pkg in "${pkgs[@]}" "${optional_pkgs[@]}" "${sddm_pkgs[@]}"; do
    yay -Qq "$pkg" &>/dev/null && to_remove+=("$pkg")
  done

  if [[ ${#to_remove[@]} -eq 0 ]]; then
    warn "No managed packages found to remove."
    return
  fi

  info "Removing packages: ${to_remove[*]}"
  yay -Rns --noconfirm "${to_remove[@]}" || warn "Some packages could not be removed (may have been removed already)."
  success "Packages removed"
}

# ── config files ──────────────────────────────────────────────────────────────
remove_configs() {
  info "Removing ~/.config entries…"

  local -a config_dirs=(
    btop cava fastfetch gtk-3.0 gtk-4.0
    hypr kitty nvim nwg-look obs-studio
    rofi spicetify swappy swaync tmux
    udiskie waybar xsettingsd yazi
  )

  for dir in "${config_dirs[@]}"; do
    local target="$HOME/.config/$dir"
    if [[ -e "$target" ]]; then
      rm -rf "$target"
      success "  Removed $target"
    fi
  done

  # environment.d envvars file
  local envvars="$HOME/.config/environment.d/envvars.conf"
  if [[ -f "$envvars" ]]; then
    rm -f "$envvars"
    success "  Removed $envvars"
    rmdir --ignore-fail-on-non-empty "$HOME/.config/environment.d"
  fi

  # mimeapps.list
  local mimeapps="$HOME/.config/mimeapps.list"
  if [[ -f "$mimeapps" ]]; then
    rm -f "$mimeapps"
    success "  Removed $mimeapps"
  fi

  info "Removing home dotfiles…"
  for f in .zshrc .tmux.conf .gtkrc-2.0; do
    if [[ -f "$HOME/$f" ]]; then
      rm -f "$HOME/$f"
      success "  Removed ~/$f"
    fi
  done

  # oh-my-zsh
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    rm -rf "$HOME/.oh-my-zsh"
    success "  Removed ~/.oh-my-zsh"
  fi

  success "Config files removed"
}

# ── sddm theme ────────────────────────────────────────────────────────────────
remove_sddm_theme() {
  local theme_dir="/usr/share/sddm/themes/sddm-astronaut-theme"
  [[ -d "$theme_dir" ]] || return

  info "Removing SDDM astronaut theme…"
  sudo systemctl disable --now sddm.service 2>/dev/null || true
  sudo rm -rf "$theme_dir"
  sudo rm -f /etc/sddm.conf /etc/sddm.conf.d/virtualkbd.conf
  success "SDDM theme removed"
}

# ── main ──────────────────────────────────────────────────────────────────────
remove_packages
remove_configs
remove_sddm_theme

echo
echo -e "${GREEN}${BOLD}Uninstall complete.${NC}"
warn "Backed-up configs (*.bak.*) were left in place — remove them manually if you wish."
warn "yay and NVIDIA drivers were NOT touched."

echo
read -rp "$(echo -e "${YELLOW}?${NC}  Reboot now? [y/N] ")" reboot_ans
if [[ "${reboot_ans,,}" == "y" ]]; then
  info "Rebooting…"
  sudo reboot now
fi
