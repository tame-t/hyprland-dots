#!/usr/bin/env bash
set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
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

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── sanity checks ─────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Linux" ]] || die "This script is for Arch Linux only."
command -v pacman &>/dev/null || die "pacman not found — is this Arch Linux?"

# ── yay ───────────────────────────────────────────────────────────────────────
install_yay() {
  if command -v yay &>/dev/null; then
    success "yay already installed"
    return
  fi
  info "Installing yay (AUR helper)…"
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm git base-devel
  local tmp
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  success "yay installed"
}

# ── make home dirs  ───────────────────────────────────────────────────────────

mkdir -p "$HOME/{"Desktop","Downloads","Documents","Iso","Music","Pictures","Usb","Videos"}/"

# ── packages ──────────────────────────────────────────────────────────────────
install_packages() {
  info "Updating system and installing packages…"
  yay -Syu --noconfirm

  yay -S --needed --noconfirm \
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

  success "Packages installed"
}

# ── optional: spotify + spicetify ────────────────────────────────────────────
install_spotify() {
  echo
  read -rp "$(echo -e "${YELLOW}?${NC}  Install Spotify + Spicetify? [y/N] ")" ans
  if [[ "${ans,,}" == "y" ]]; then
    info "Installing Spotify + Spicetify…"
    yay -S --needed --noconfirm spotify spicetify-cli
    success "Spotify + Spicetify installed"

    if [[ -d "$DOTS_DIR/.config/spicetify" ]]; then
      info "Copying Spicetify config…"
      mkdir -p "$HOME/.config/spicetify"
      cp -r "$DOTS_DIR/.config/spicetify/." "$HOME/.config/spicetify/"
      success "Spicetify config copied"
    fi
  fi
}

# ── backup helper ─────────────────────────────────────────────────────────────
backup() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    local bak="${target}.bak.$(date +%Y%m%d_%H%M%S)"
    warn "Backing up existing $(basename "$target") → $bak"
    mv "$target" "$bak"
  fi
}

# ── copy dotfiles ─────────────────────────────────────────────────────────────
copy_configs() {
  info "Copying configs to ~/.config/…"
  mkdir -p "$HOME/.config"

  for src in "$DOTS_DIR/.config"/*/; do
    name="$(basename "$src")"
    dest="$HOME/.config/$name"
    backup "$dest"
    cp -r "$src" "$dest"
  done

  # environment.d file (nested — handle separately)
  mkdir -p "$HOME/.config/environment.d"
  cp "$DOTS_DIR/.config/environment.d/envvars.conf" \
    "$HOME/.config/environment.d/envvars.conf"

  # mimeapps.list
  backup "$HOME/.config/mimeapps.list"
  cp "$DOTS_DIR/.config/mimeapps.list" "$HOME/.config/mimeapps.list"

  success "Configs copied"

  info "Copying home dotfiles…"
  for f in .zshrc .tmux.conf .gtkrc-2.0; do
    if [[ -f "$DOTS_DIR/$f" ]]; then
      backup "$HOME/$f"
      cp "$DOTS_DIR/$f" "$HOME/$f"
      success "  $f → ~/"
    fi
  done
}

# ── oh-my-zsh ─────────────────────────────────────────────────────────────────
install_omz() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    success "oh-my-zsh already installed"
    return
  fi
  info "Installing oh-my-zsh…"
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "oh-my-zsh installed"
}

# ── default shell ─────────────────────────────────────────────────────────────
set_zsh_default() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "$SHELL" == "$zsh_path" ]]; then
    success "zsh is already the default shell"
    return
  fi
  info "Setting zsh as default shell…"
  grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
  chsh -s "$zsh_path"
  success "Default shell set to zsh (takes effect on next login)"
}

# ── wallpaper directory ───────────────────────────────────────────────────────
setup_wallpaper_dir() {
  local wp_dir="$HOME/Pictures/Wallpaper"
  if [[ ! -d "$wp_dir" ]]; then
    info "Creating wallpaper directory at $wp_dir…"
    mkdir -p "$wp_dir"
    warn "Drop your wallpaper at $wp_dir/wallpaper.png (expected by hyprland.conf)"
  else
    success "Wallpaper directory already exists"
  fi
}

# ── xdg user dirs ─────────────────────────────────────────────────────────────
setup_xdg() {
  command -v xdg-user-dirs-update &>/dev/null && xdg-user-dirs-update
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${BOLD}Hyprland Catppuccin Mocha Dotfiles Installer${NC}\n"

  install_yay
  install_packages
  install_omz
  copy_configs
  set_zsh_default
  setup_wallpaper_dir
  setup_xdg
  install_spotify

  echo
  echo -e "${GREEN}${BOLD}All done!${NC}"
  echo -e "  • Log out and select Hyprland from your display manager to start."
  echo -e "  • Place your wallpaper at ${BOLD}~/Pictures/Wallpaper/wallpaper.png${NC}."
  echo -e "  • Any previous configs were backed up with a ${BOLD}.bak.TIMESTAMP${NC} suffix."
}

main "$@"
