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

mkdir -p "$HOME"/{Desktop,Downloads,Documents,Iso,Music,Pictures,Usb,Videos}

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

# ── optional: sddm astronaut theme ───────────────────────────────────────────
install_sddm_theme() {
  echo
  read -rp "$(echo -e "${YELLOW}?${NC}  Install SDDM Astronaut Theme? [y/N] ")" ans
  [[ "${ans,,}" != "y" ]] && return

  local theme_name="sddm-astronaut-theme"
  local theme_repo="https://github.com/Keyitdev/sddm-astronaut-theme.git"
  local themes_dir="/usr/share/sddm/themes"
  local clone_dir
  clone_dir="$(mktemp -d)"
  local date_stamp
  date_stamp="$(date +%s)"

  local -a theme_variants=(
    "astronaut" "black_hole" "cyberpunk" "hyprland_kath" "jake_the_dog"
    "japanese_aesthetic" "pixel_sakura" "pixel_sakura_static"
    "post-apocalyptic_hacker" "purple_leaves"
  )

  info "Installing SDDM and Qt6 dependencies…"
  sudo pacman --needed -S sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg
  success "SDDM dependencies installed"

  info "Cloning sddm-astronaut-theme…"
  git clone -b master --depth 1 "$theme_repo" "$clone_dir/$theme_name"
  success "Repository cloned"

  local dst="$themes_dir/$theme_name"
  [[ -d "$dst" ]] && sudo mv "$dst" "${dst}_$date_stamp"
  sudo mkdir -p "$dst"

  info "Installing theme files…"
  sudo cp -r "$clone_dir/$theme_name"/. "$dst"/
  [[ -d "$dst/Fonts" ]] && sudo cp -r "$dst/Fonts"/. /usr/share/fonts/
  success "Theme files installed"

  printf '[Theme]\nCurrent=%s\n' "$theme_name" | sudo tee /etc/sddm.conf >/dev/null
  sudo mkdir -p /etc/sddm.conf.d
  printf '[General]\nInputMethod=qtvirtualkeyboard\n' | sudo tee /etc/sddm.conf.d/virtualkbd.conf >/dev/null

  echo
  info "Select a theme variant:"
  local theme_variant
  select theme_variant in "${theme_variants[@]}"; do
    [[ -n "$theme_variant" ]] && break
  done
  sudo sed -i "s|^ConfigFile=.*|ConfigFile=Themes/${theme_variant}.conf|" "$dst/metadata.desktop"
  success "Theme variant set to: $theme_variant"

  info "Enabling SDDM service…"
  sudo systemctl disable display-manager.service 2>/dev/null || true
  sudo systemctl enable --now sddm.service
  success "SDDM enabled — reboot required"

  rm -rf "$clone_dir"
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

# ── gpu driver detection & installation ───────────────────────────────────────

# Returns the correct NVIDIA driver package name for the detected GPU.
# Detection order: chip codename prefix → model-name keyword fallback.
_nvidia_driver_pkg() {
  local gpu_line="$1"

  # Chip codenames from lspci e.g. "GP104 [GeForce GTX 1080]", "TU116", "GA102", "AD102", "GB202"
  local chip_code chip_prefix
  chip_code=$(echo "$gpu_line" | grep -oE '\b[A-Z]{2}[0-9]{2,3}[A-Z]?\b' | head -1 || true)
  chip_prefix="${chip_code:0:2}"

  # Maxwell Gen 1 (GTX 750 / 750 Ti) was dropped from the 530+ driver; needs the 525xx AUR branch.
  # Must be checked before the GM prefix case which covers Maxwell Gen 2 (GM200+).
  case "$chip_code" in
    GM107|GM108) echo "nvidia-525xx-dkms" ; return ;;
  esac

  case "$chip_prefix" in
    GB|AD|GA|TU|GP|GM) echo "nvidia"            ; return ;;  # Maxwell Gen 2 → Blackwell
    GK)                 echo "nvidia-470xx-dkms" ; return ;;  # Kepler (GTX 600 / 700)
    GF)                 echo "nvidia-390xx-dkms" ; return ;;  # Fermi  (GTX 400 / 500)
  esac

  # Fallback: match on the human-readable model name
  if echo "$gpu_line" | grep -qiE 'GTX 750( Ti)?([^0-9]|$)'; then
    echo "nvidia-525xx-dkms"  # Maxwell Gen 1 by model name when chip code is absent
  elif echo "$gpu_line" | grep -qiE 'RTX|GTX 16[0-9]{2}|GTX 1[0-9]{3}|GTX 9[0-9]{2}'; then
    echo "nvidia"
  elif echo "$gpu_line" | grep -qiE 'GTX [78][0-9]{2}|GTX 6[0-9]{2}'; then
    echo "nvidia-470xx-dkms"
  elif echo "$gpu_line" | grep -qiE 'GTX [45][0-9]{2}|GTS [0-9]'; then
    echo "nvidia-390xx-dkms"
  else
    warn "Unrecognised NVIDIA chip '${chip_code:-?}' — defaulting to current driver"
    echo "nvidia"
  fi
}

# Installs kernel headers for every kernel present on the system (needed by DKMS).
_install_kernel_headers() {
  local found=false
  for kernel in linux linux-zen linux-lts linux-hardened linux-cachyos; do
    if pacman -Qq "$kernel" &>/dev/null; then
      sudo pacman -S --needed --noconfirm "${kernel}-headers"
      found=true
    fi
  done
  if ! $found; then
    warn "Could not detect a known kernel package — install kernel headers manually for DKMS"
  fi
}

_install_nvidia() {
  local gpu_line="$1"
  local gpu_name
  gpu_name=$(echo "$gpu_line" | sed 's/.*: //' | sed 's/ (rev.*//')
  info "NVIDIA GPU detected: $gpu_name"

  local drv
  drv=$(_nvidia_driver_pkg "$gpu_line")

  # Non-default kernels (linux-zen, linux-lts, etc.) need the dkms variant
  if [[ "$drv" == "nvidia" ]] && ! pacman -Qq linux &>/dev/null; then
    drv="nvidia-dkms"
    info "Non-default kernel detected — switching to nvidia-dkms"
  fi

  info "Driver package: $drv"

  case "$drv" in
    nvidia|nvidia-dkms)
      [[ "$drv" == "nvidia-dkms" ]] && _install_kernel_headers
      yay -S --needed --noconfirm "$drv" nvidia-utils nvidia-settings libva-nvidia-driver
      ;;
    nvidia-525xx-dkms)
      # nvidia-525xx-dkms has exact-version deps on nvidia-525xx and nvidia-525xx-utils;
      # all three must be installed together so AUR can satisfy them in one transaction.
      _install_kernel_headers
      yay -S --needed --noconfirm nvidia-525xx nvidia-525xx-dkms nvidia-525xx-utils
      ;;
    nvidia-470xx-dkms)
      _install_kernel_headers
      yay -S --needed --noconfirm nvidia-470xx-dkms nvidia-470xx-utils
      ;;
    nvidia-390xx-dkms)
      _install_kernel_headers
      yay -S --needed --noconfirm nvidia-390xx-dkms nvidia-390xx-utils
      ;;
  esac

  # DRM kernel modesetting — mandatory for Wayland compositors
  if [[ ! -f /etc/modprobe.d/nvidia.conf ]] || ! grep -q 'modeset=1' /etc/modprobe.d/nvidia.conf 2>/dev/null; then
    echo "options nvidia-drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
    info "DRM modesetting enabled (/etc/modprobe.d/nvidia.conf)"
  fi

  # Early KMS — add NVIDIA modules to the initramfs
  local mkinit_cfg="/etc/mkinitcpio.conf"
  if [[ -f "$mkinit_cfg" ]] && ! grep -q 'nvidia' "$mkinit_cfg"; then
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$mkinit_cfg"
    sudo mkinitcpio -P
    info "NVIDIA modules added to mkinitcpio and initramfs rebuilt"
  fi

  success "NVIDIA drivers installed — reboot required"
}

_install_amd() {
  local gpu_line="$1"
  local gpu_name
  gpu_name=$(echo "$gpu_line" | sed 's/.*: //' | sed 's/ (rev.*//')
  info "AMD GPU detected: $gpu_name"

  # Pre-GCN chips (HD 6000 and older) use the legacy radeon kernel driver
  if echo "$gpu_line" | grep -qiE \
    '\b(Cedar|Redwood|Juniper|Cypress|Hemlock|Barts|Caicos|Turks|Cayman|Antilles|Wrestler|Ontario|Zacate|Llano|Trinity|Richland|RV[0-9]{3}|RS[0-9]{3})\b'; then
    info "Pre-GCN AMD GPU — installing legacy ATI driver…"
    sudo pacman -S --needed --noconfirm mesa libva-mesa-driver xf86-video-ati
    success "AMD legacy (ATI) drivers installed"
  else
    # GCN and newer (HD 7700+, RX series, RDNA 1/2/3/4, APUs Kaveri+)
    info "GCN+ AMD GPU — installing open-source AMDGPU drivers…"
    sudo pacman -S --needed --noconfirm mesa vulkan-radeon libva-mesa-driver mesa-vdpau
    success "AMD drivers installed"
  fi
}

install_gpu_drivers() {
  info "Detecting GPU…"

  # Make sure lspci is available
  command -v lspci &>/dev/null || sudo pacman -S --needed --noconfirm pciutils

  local gpu_info
  gpu_info=$(lspci 2>/dev/null | grep -iE '(vga compatible controller|3d controller|display controller)') || true

  if [[ -z "$gpu_info" ]]; then
    warn "No GPU found via lspci — skipping driver installation"
    return
  fi

  local nvidia_line amd_line intel_line
  nvidia_line=$(echo "$gpu_info" | grep -i 'nvidia'             || true)
  amd_line=$(   echo "$gpu_info" | grep -iE '(amd|ati|radeon)' || true)
  intel_line=$( echo "$gpu_info" | grep -i 'intel'             || true)

  if [[ -n "$nvidia_line" ]]; then
    _install_nvidia "$nvidia_line"
  elif [[ -n "$amd_line" ]]; then
    _install_amd "$amd_line"
  elif [[ -n "$intel_line" ]]; then
    # Intel integrated: i915 kernel driver is built-in, mesa is pulled by compositor deps
    info "Intel integrated graphics detected — no additional drivers required"
  else
    warn "GPU vendor not recognised — skipping driver installation"
    warn "Detected: $(echo "$gpu_info" | head -1)"
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${BOLD}Hyprland Catppuccin Mocha Dotfiles Installer${NC}\n"

  install_yay
  install_packages
  install_gpu_drivers
  install_omz
  copy_configs
  set_zsh_default
  setup_wallpaper_dir
  setup_xdg
  install_spotify
  install_sddm_theme

  echo
  echo -e "${GREEN}${BOLD}All done!${NC}"
  echo -e "  • Log out and select Hyprland from your display manager to start."
  echo -e "  • Place your wallpaper at ${BOLD}~/Pictures/Wallpaper/wallpaper.png${NC}."
  echo -e "  • Any previous configs were backed up with a ${BOLD}.bak.TIMESTAMP${NC} suffix."

  echo
  read -rp "$(echo -e "${YELLOW}?${NC}  Reboot now? [y/N] ")" ans
  [[ "${ans,,}" == "y" ]] && sudo reboot
}

main "$@"
