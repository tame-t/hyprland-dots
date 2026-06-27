#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}::${NC} $*"; }
success() { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}!${NC}  $*"; }
die() {
  echo -e "${RED}✗${NC}  $*" >&2
  exit 1
}

[[ "$(uname -s)" == "Linux" ]] || die "This script is for Arch Linux only."
command -v pacman &>/dev/null || die "pacman not found — is this Arch Linux?"

echo -e "\n${BOLD}${RED}Hyprland Dotfiles — FULL Uninstall${NC}\n"
warn "This will remove ALL installed packages including NVIDIA drivers and yay,"
warn "revert system config files, and delete all copied dotfiles."
echo
read -rp "$(echo -e "${RED}!${NC}  Type YES to continue: ")" ans
[[ "$ans" == "YES" ]] || {
  info "Aborted."
  exit 0
}

# ── helper: remove packages that are actually installed ───────────────────────
remove_if_installed() {
  local manager="$1"
  shift
  local -a candidates=("$@")
  local -a present=()
  for pkg in "${candidates[@]}"; do
    pacman -Qq "$pkg" &>/dev/null && present+=("$pkg")
  done
  [[ ${#present[@]} -eq 0 ]] && return
  info "Removing: ${present[*]}"
  if [[ "$manager" == "yay" ]] && command -v yay &>/dev/null; then
    yay -Rns --noconfirm "${present[@]}" || warn "Some packages could not be removed."
  else
    sudo pacman -Rns --noconfirm "${present[@]}" || warn "Some packages could not be removed."
  fi
}

# ── 1. main packages ──────────────────────────────────────────────────────────
remove_main_packages() {
  info "Removing main packages…"
  remove_if_installed yay \
    hyprland waybar rofi-wayland kitty \
    zsh oh-my-zsh-git zsh-autosuggestions \
    fastfetch btop cava yazi \
    swappy grim slurp wl-clipboard \
    swaync udiskie network-manager-applet \
    networkmanager bluez bluez-utils \
    pipewire wireplumber pipewire-pulse pavucontrol brightnessctl \
    neovim tmux obs-studio nwg-look \
    ttf-fira-code nerd-fonts-fira-code \
    xdg-desktop-portal-hyprland xdg-user-dirs \
    awww
  success "Main packages removed"
}

# ── 2. optional packages (spotify / sddm) ────────────────────────────────────
remove_optional_packages() {
  info "Removing optional packages (Spotify, SDDM)…"
  remove_if_installed yay spotify spicetify-cli
  remove_if_installed pacman sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg
  success "Optional packages removed"
}

# ── 3. nvidia packages ───────────────────────────────────────────────────────
remove_nvidia_packages() {
  info "Removing NVIDIA packages…"
  remove_if_installed pacman \
    nvidia nvidia-dkms nvidia-utils nvidia-settings \
    lib32-nvidia-utils nvidia-open nvidia-open-dkms
  success "NVIDIA packages removed"
}

# ── 4. revert mkinitcpio.conf ─────────────────────────────────────────────────
revert_mkinitcpio() {
  local config="/etc/mkinitcpio.conf"
  [[ -f "$config" ]] || return

  info "Reverting $config…"
  # Restore from .bak if install.sh left one, otherwise manually revert
  if [[ -f "${config}.bak" ]]; then
    sudo cp "${config}.bak" "$config"
    info "  Restored from ${config}.bak"
  else
    # Remove nvidia modules from MODULES=()
    sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "$config"
    # Clean up extra spaces inside parens
    sudo sed -i 's/( */(/g; s/ *)/)/g; s/  \+/ /g' "$config"
    # Re-add kms hook after modconf if missing
    if ! grep -q '\bkms\b' "$config"; then
      sudo sed -i 's/\bmodconf\b/modconf kms/' "$config"
    fi
    info "  Manually reverted nvidia entries"
  fi
  success "mkinitcpio.conf reverted"
}

# ── 5. remove nvidia modprobe config ─────────────────────────────────────────
revert_modprobe() {
  local config="/etc/modprobe.d/nvidia.conf"
  if [[ -f "$config" ]]; then
    info "Removing $config…"
    sudo rm -f "$config"
    success "modprobe nvidia.conf removed"
  fi
}

# ── 6. revert /etc/default/grub ──────────────────────────────────────────────
revert_grub_default() {
  local config="/etc/default/grub"
  [[ -f "$config" ]] || return

  info "Reverting $config…"
  if [[ -f "${config}.bak" ]]; then
    sudo cp "${config}.bak" "$config"
    info "  Restored from ${config}.bak"
  else
    sudo sed -i 's/ *nvidia_drm\.modeset=1//g' "$config"
    info "  Removed nvidia_drm.modeset=1"
  fi
  success "/etc/default/grub reverted"
}

# ── 7. regenerate initramfs + grub ────────────────────────────────────────────
rebuild_boot() {
  if command -v mkinitcpio &>/dev/null; then
    info "Regenerating initramfs…"
    sudo mkinitcpio -P || warn "mkinitcpio failed — check /etc/mkinitcpio.conf manually."
    success "initramfs regenerated"
  fi

  if command -v grub-mkconfig &>/dev/null && [[ -f /boot/grub/grub.cfg ]]; then
    info "Updating GRUB config…"
    sudo grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed."
    success "GRUB config updated"
  fi
}

# ── 8. sddm theme ────────────────────────────────────────────────────────────
remove_sddm_theme() {
  local theme_dir="/usr/share/sddm/themes/sddm-astronaut-theme"
  [[ -d "$theme_dir" ]] || return

  info "Removing SDDM astronaut theme…"
  sudo systemctl disable --now sddm.service 2>/dev/null || true
  sudo rm -rf "$theme_dir"
  sudo rm -f /etc/sddm.conf /etc/sddm.conf.d/virtualkbd.conf
  rmdir --ignore-fail-on-non-empty /etc/sddm.conf.d 2>/dev/null || true
  success "SDDM theme removed"
}

# ── 9. chaotic AUR ───────────────────────────────────────────────────────────
remove_chaotic_aur() {
  [[ -f "/etc/pacman.d/chaotic-mirrorlist" ]] || return

  info "Removing Chaotic AUR…"
  # Strip the [chaotic-aur] block from pacman.conf
  sudo sed -i '/^\[chaotic-aur\]/,/^Include.*chaotic-mirrorlist/d' /etc/pacman.conf
  # Remove the keyring and mirrorlist packages
  remove_if_installed pacman chaotic-keyring chaotic-mirrorlist
  sudo rm -f /etc/pacman.d/chaotic-mirrorlist
  sudo pacman -Syy --noconfirm 2>/dev/null || true
  success "Chaotic AUR removed"
}

# ── 10. config files ──────────────────────────────────────────────────────────
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

  local envvars="$HOME/.config/environment.d/envvars.conf"
  if [[ -f "$envvars" ]]; then
    rm -f "$envvars"
    rmdir --ignore-fail-on-non-empty "$HOME/.config/environment.d"
    success "  Removed $envvars"
  fi

  local mimeapps="$HOME/.config/mimeapps.list"
  [[ -f "$mimeapps" ]] && rm -f "$mimeapps" && success "  Removed $mimeapps"

  info "Removing home dotfiles…"
  for f in .zshrc .tmux.conf .gtkrc-2.0; do
    [[ -f "$HOME/$f" ]] && rm -f "$HOME/$f" && success "  Removed ~/$f"
  done

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    rm -rf "$HOME/.oh-my-zsh"
    success "  Removed ~/.oh-my-zsh"
  fi

  success "Config files removed"
}

# ── 11. revert default shell ──────────────────────────────────────────────────
revert_shell() {
  local bash_path
  bash_path="$(command -v bash 2>/dev/null)" || return
  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"

  if [[ "$current_shell" == "$(command -v zsh 2>/dev/null)" ]]; then
    info "Reverting default shell to bash…"
    chsh -s "$bash_path"
    success "Default shell reverted to bash (takes effect on next login)"
  fi
}

# ── 12. remove yay ───────────────────────────────────────────────────────────
remove_yay() {
  if pacman -Qq yay &>/dev/null; then
    info "Removing yay…"
    sudo pacman -Rns --noconfirm yay || warn "Could not remove yay — remove it manually."
    success "yay removed"
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────
remove_main_packages
remove_optional_packages
remove_nvidia_packages
revert_mkinitcpio
revert_modprobe
revert_grub_default
rebuild_boot
remove_sddm_theme
remove_chaotic_aur
remove_configs
revert_shell
remove_yay

echo
echo -e "${GREEN}${BOLD}Full uninstall complete.${NC}"
warn "Backup files (*.bak / *.bak.*) were left in place — remove them manually if needed."

echo
read -rp "$(echo -e "${YELLOW}?${NC}  Reboot now? [y/N] ")" reboot_ans
if [[ "${reboot_ans,,}" == "y" ]]; then
  info "Rebooting…"
  sudo reboot now
fi
