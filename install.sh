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

# ── optional: nvidia drivers ──────────────────────────────────────────────────
#
# Sourced from Nvidiainstall by Justus0405 (MIT)
# https://github.com/Justus0405/Nvidiainstall

_nv_script_version="2.5"
_nv_legacy_mode="false"

# Nvidia colour codes (lowercase — no collision with install.sh's uppercase vars)
black="\e[1;30m"      red="\e[1;31m"         green="\e[1;32m"
yellow="\e[1;33m"     blue="\e[1;34m"        purple="\e[1;35m"
cyan="\e[1;36m"       lightGray="\e[1;37m"   gray="\e[1;90m"
lightRed="\e[1;91m"   lightGreen="\e[1;92m"  lightYellow="\e[1;93m"
lightBlue="\e[1;94m"  lightPurple="\e[1;95m" lightCyan="\e[1;96m"
white="\e[1;97m"      bold="\e[1m"           faint="\e[2m"
italic="\e[3m"        underlined="\e[4m"     blinking="\e[5m"
reset="\e[0m"

logMessage() {
    local type="$1"
    local message="$2"
    case "${type}" in
    "info" | "INFO")
        echo -e "${gray}[${cyan}i${gray}]${reset} ${message}"
        ;;
    "done" | "DONE")
        echo -e "${gray}[${green}✓${gray}]${reset} ${message}"
        exit 0
        ;;
    "warning" | "WARNING")
        echo -e "${gray}[${red}!${gray}]${reset} ${message}"
        ;;
    "error" | "ERROR")
        echo -e "${red}ERROR${reset}: ${message}"
        exit 1
        ;;
    *)
        echo -e "[UNDEFINED] ${message}"
        ;;
    esac
}

checkAurHelper() {
    if command -v yay >/dev/null 2>&1; then
        logMessage "info" "Yay is installed."
    else
        logMessage "info" "Yay is not installed."
        installAurHelper
    fi
}

installAurHelper() {
    local targetUser="${SUDO_USER:-$(whoami)}"
    logMessage "info" "Installing yay..."
    sudo -u "${targetUser}" bash <<'EOF'
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
EOF
    logMessage "info" "Sucessfully installed yay."
}

aurHelperInstall() {
    local packages="$1"
    local targetUser="${SUDO_USER:-$(whoami)}"
    # shellcheck disable=SC2086
    sudo -u "${targetUser}" yay -S --needed --noconfirm ${packages}
}

aurHelperUninstall() {
    local packages="$1"
    local targetUser="${SUDO_USER:-$(whoami)}"
    # shellcheck disable=SC2086
    sudo -u "${targetUser}" yay -R --noconfirm ${packages}
}

checkChaoticAur() {
    if [[ -f "/etc/pacman.d/chaotic-mirrorlist" ]]; then
        logMessage "info" "Chaotic AUR is installed."
    else
        logMessage "warning" "Chaotic AUR is not installed."
        installChaoticAUR
    fi
}

installChaoticAUR() {
    logMessage "info" "Installing the Chaotic AUR..."

    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB

    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    sudo tee -a "/etc/pacman.conf" >/dev/null <<EOF
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

    sudo pacman -Syy

    logMessage "info" "Successfully installed the Chaotic AUR."
}

checkNvidia() {
    gpuGen="Unknown"
    gpuDriver="Unknown"

    gpuInfo=$(lspci -nn | grep -i 'VGA.*NVIDIA')
    gpuName=$(echo "${gpuInfo}" | sed -E 's/.*NVIDIA Corporation //; s/ \[.*//')

    case "${gpuName}" in
    *"GB10"* | *"GB20"*)
        gpuGen="Blackwell"
        gpuDriver="nvidia-open-dkms"
        ;;
    *"GH10"*)
        gpuGen="Hopper"
        gpuDriver="nvidia-open-dkms"
        ;;
    *"AD10"*)
        gpuGen="Ada Lovelace"
        gpuDriver="nvidia-open-dkms"
        ;;
    *"GA10"*)
        gpuGen="Ampere"
        gpuDriver="nvidia-open-dkms"
        ;;
    *"TU10"* | *"TU11"*)
        gpuGen="Turing"
        gpuDriver="nvidia-open-dkms"
        ;;
    *"GV10"*)
        gpuGen="Volta"
        gpuDriver="nvidia-580xx-dkms"
        ;;
    *"GP10"*)
        gpuGen="Pascal"
        gpuDriver="nvidia-580xx-dkms"
        ;;
    *"GM10"* | *"GM20"*)
        gpuGen="Maxwell"
        gpuDriver="nvidia-580xx-dkms"
        ;;
    *"EXK107"* | *"GK10"* | *"GK11"* | *"GK18"* | *"GK20"* | *"GK21"*)
        gpuGen="Kepler"
        gpuDriver="nvidia-470xx-dkms"
        ;;
    *"EXMF1"* | *"GF10"* | *"GF11"*)
        gpuGen="Fermi"
        gpuDriver="nvidia-390xx-dkms"
        ;;
    *"Kal-El"* | *"Tegra 2"* | *"Wayne"*)
        gpuGen="VLIW Vec4"
        gpuDriver="nvidia-390xx-dkms"
        ;;
    *"C77"* | *"C78"* | *"C79"* | *"C7A"* | *"G80"* | *"G84"* | *"G86"* | *"G92"* | *"G94"* | *"G96"* | *"G98"* | *"ION"* | *"C87"* | *"C89"* | *"GT20"* | *"GT21"*)
        gpuGen="Tesla"
        gpuDriver="nvidia-340xx-dkms"
        ;;
    *"C51"* | *"C61"* | *"C67"* | *"C68"* | *"C73"* | *"G70"* | *"G71"* | *"G72"* | *"G73"* | *"NV40"* | *"NV41"* | *"NV42"* | *"NV43"* | *"NV44"* | *"NV45"* | *"NV48"* | *"RSX"*)
        gpuGen="Curie"
        gpuDriver="unsupported"
        ;;
    *"NV30"* | *"NV31"* | *"NV34"* | *"NV35"* | *"NV36"* | *"NV37"* | *"NV38"* | *"NV39"*)
        gpuGen="Rankine"
        gpuDriver="unsupported"
        ;;
    *"NV20"* | *"NV25"* | *"NV28"* | *"NV2A"*)
        gpuGen="Kelvin"
        gpuDriver="unsupported"
        ;;
    *"Crush1"* | *"NV10"* | *"NV11"* | *"NV15"* | *"NV17"* | *"NV18"*)
        gpuGen="Celsius"
        gpuDriver="unsupported"
        ;;
    *"NV4"* | *"NV5"*)
        gpuGen="Fahrenheit"
        gpuDriver="unsupported"
        ;;
    *)
        gpuGen="Unknown"
        gpuDriver="unidentified"
        ;;
    esac

    if [[ ${gpuDriver} == "unsupported" ]]; then
        logMessage "error" "${gpuGen} is not supported anymore."
    fi

    if [[ ${gpuDriver} == "unidentified" ]]; then
        chooseGpuDriver
    fi

    if [[ -z ${gpuName} ]]; then
        gpuName="Unkown"
    fi
}

checkInstalledDriver() {
    legacyDriver=$(pacman -Qq | grep -E '^nvidia$')
    installedDriver=$(pacman -Qq | grep -E 'nvidia-(dkms|open-dkms|470xx-dkms|390xx-dkms|340xx-dkms)')

    if [[ -n ${legacyDriver} ]]; then
        installedDriver="nvidia"
    fi

    if [[ -z ${installedDriver} ]]; then
        installedDriver="none"
    fi
}

chooseGpuDriver() {
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     We could not identify your GPU.      │"
    echo -e "\t│  /  #  \    Please select which driver you       │"
    echo -e "\t│ /_______\   want to manage.                      │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [!] Curie and older are not supported anymore!   │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│                                                  │"
    echo -e "\t│ [1] nvidia-open-dkms          [Turing and newer] │"
    echo -e "\t│ [2] nvidia-580xx-dkms   [Maxwell, Pascal, Volta] │"
    echo -e "\t│ [3] nvidia-470xx-dkms                   [Kepler] │"
    echo -e "\t│ [4] nvidia-390xx-dkms                    [Fermi] │"
    echo -e "\t│ [5] nvidia-340xx-dkms                    [Tesla] │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│ [0] Quit                                         │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,...,0]${reset}"

    read -rsn1 option

    case "${option}" in
    "1")
        gpuDriver="nvidia-open-dkms"
        ;;
    "2")
        gpuDriver="nvidia-580xx-dkms"
        ;;
    "3")
        gpuDriver="nvidia-470xx-dkms"
        ;;
    "4")
        gpuDriver="nvidia-390xx-dkms"
        ;;
    "5")
        gpuDriver="nvidia-340xx-dkms"
        ;;
    "0")
        exitScript "Quit."
        ;;
    *)
        chooseGpuDriver
        ;;
    esac
}

backupConfig() {
    local config="$1"
    logMessage "info" "Creating backup of ${config}"
    sudo cp "${config}" "${config}.bak"
    logMessage "info" "Backup of ${config} created."
}

showMenu() {
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│                                                  │"
    echo -e "\t│ Choose option:                                   │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [1] Install                                      │"
    echo -e "\t│ [2] Uninstall                                    │"
    echo -e "\t│ [3] Device Information                           │"
    echo -e "\t│ [4] About Nvidiainstall                          │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│ [0] Quit                                         │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,...,0]${reset}"

    read -rsn1 option

    case "${option}" in
    "1")
        if [[ ${installedDriver} == "none" ]]; then
            confirmInstallation
        else
            showDriverInstalled
        fi
        ;;
    "2")
        if [[ ${installedDriver} == "none" ]]; then
            showNoDriverInstalled
        else
            confirmUninstallation
        fi
        ;;
    "3")
        showDeviceInformation
        ;;
    "4")
        showAbout
        ;;
    "0")
        exitScript "Quit."
        ;;
    *)
        showMenu
        ;;
    esac

    showMenu
}

showDeviceInformation() {
    clear
    echo -e ""
    echo -e "\tDevice Information:"
    echo -e ""
    echo -e "\tDetected GPU: ${gpuName}"
    echo -e "\tGeneration: ${gpuGen}"
    echo -e "\tInstalled Driver: ${installedDriver}"
    echo -e ""
    echo -e "\tSelected Driver: ${gpuDriver}"
    echo -e "\tLegacy Mode: ${_nv_legacy_mode}"
    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;
    esac
}

showAbout() {
    githubResponse=$(curl -s "https://api.github.com/repos/Justus0405/Nvidiainstall/contributors")
    clear
    echo -e ""
    echo -e "\tAbout Nvidiainstall:"
    echo -e ""
    echo -e "\tVersion: ${_nv_script_version}"
    echo -e "\tAuthor : Justus0405"
    echo -e "\tSource : https://github.com/Justus0405/Nvidiainstall"
    echo -e "\tLicense: MIT"
    echo -e "\tContributors:"

    echo "${githubResponse}" | grep '"login":' | awk -F '"' '{print $4}' | while read -r contributors; do
        echo -e "\t\t\e[0;35m${contributors}\e[m"
    done

    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;
    esac
}

showDriverInstalled() {
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     You already have other NVIDIA dkms   │"
    echo -e "\t│  /  #  \    packages Installed!                  │"
    echo -e "\t│ /_______\                                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\tInstalled Package: ${installedDriver}"
    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;
    esac
}

showNoDriverInstalled() {
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     We could not find any installed      │"
    echo -e "\t│  /  #  \    NVIDIA dkms packages!                │"
    echo -e "\t│ /_______\                                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;
    esac
}

confirmInstallation() {
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     This script will install NVIDIA      │"
    echo -e "\t│  /  #  \    drivers and modify system            │"
    echo -e "\t│ /_______\   configurations.                      │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [!] Proceed with caution!                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    read -rp "Do you want to install ${gpuDriver}? (y/N): " confirm
    case "${confirm}" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Installing ${gpuDriver}...${reset}"
        installationSteps
        ;;
    *)
        exitScript "Installation cancelled."
        ;;
    esac
}

installationSteps() {
    updateSystem
    checkKernelHeaders
    installNvidiaPackages
    configureMkinitcpio
    configureModprobe
    configureGrubDefault
    regenerateInitramfs
    updateGrubConfig
    confirmReboot
}

updateSystem() {
    logMessage "info" "Updating System..."
    sudo pacman -Syyu --noconfirm
    logMessage "info" "Updated System."
}

checkKernelHeaders() {
    logMessage "info" "Installing Kernel Modules..."
    kernel=$(uname -r)
    if [[ "${kernel}" == *"zen"* ]]; then
        logMessage "info" "Detected Kernel: linux-zen"
        sudo pacman -S --needed --noconfirm linux-zen-headers
    elif [[ "${kernel}" == *"lts"* ]]; then
        logMessage "info" "Detected Kernel: linux-lts"
        sudo pacman -S --needed --noconfirm linux-lts-headers
    elif [[ "$kernel" == *"hardened"* ]]; then
        logMessage "info" "Detected Kernel: linux-hardened"
        sudo pacman -S --needed --noconfirm linux-hardened-headers
    else
        logMessage "info" "Detected Kernel: linux"
        sudo pacman -S --needed --noconfirm linux-headers
    fi
    logMessage "info" "Installed Kernel Modules."
}

installNvidiaPackages() {
    logMessage "info" "Identified Generation: ${gpuGen}"
    logMessage "info" "Installing ${gpuDriver} and dependencies..."

    case "${gpuDriver}" in
    "nvidia-open-dkms")
        sudo pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils opencl-nvidia nvidia-settings libglvnd lib32-nvidia-utils lib32-opencl-nvidia egl-wayland
        ;;
    "nvidia-580xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperInstall "nvidia-580xx-dkms nvidia-580xx-utils opencl-nvidia-580xx nvidia-580xx-settings libglvnd lib32-nvidia-580xx-utils lib32-opencl-nvidia-580xx egl-wayland"
        else
            checkChaoticAur
            sudo pacman -S --needed --noconfirm nvidia-580xx-dkms nvidia-580xx-utils opencl-nvidia-580xx nvidia-580xx-settings libglvnd lib32-nvidia-580xx-utils lib32-opencl-nvidia-580xx egl-wayland
        fi
        ;;
    "nvidia-470xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperInstall "nvidia-470xx-dkms nvidia-470xx-utils opencl-nvidia-470xx nvidia-470xx-settings libglvnd lib32-nvidia-470xx-utils lib32-opencl-nvidia-470xx egl-wayland"
        else
            checkChaoticAur
            sudo pacman -S --needed --noconfirm nvidia-470xx-dkms nvidia-470xx-utils opencl-nvidia-470xx nvidia-470xx-settings libglvnd lib32-nvidia-470xx-utils lib32-opencl-nvidia-470xx egl-wayland
        fi
        ;;
    "nvidia-390xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperInstall "nvidia-390xx-dkms nvidia-390xx-utils opencl-nvidia-390xx nvidia-390xx-settings libglvnd lib32-nvidia-390xx-utils lib32-opencl-nvidia-390xx egl-wayland"
        else
            checkChaoticAur
            sudo pacman -S --needed --noconfirm nvidia-390xx-dkms nvidia-390xx-utils opencl-nvidia-390xx nvidia-390xx-settings libglvnd lib32-nvidia-390xx-utils lib32-opencl-nvidia-390xx egl-wayland
        fi
        ;;
    "nvidia-340xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperInstall "nvidia-340xx-dkms nvidia-340xx-utils opencl-nvidia-340xx libglvnd lib32-nvidia-340xx-utils lib32-opencl-nvidia-340xx egl-wayland"
        else
            checkChaoticAur
            sudo pacman -S --needed --noconfirm nvidia-340xx-dkms nvidia-340xx-utils opencl-nvidia-340xx libglvnd egl-wayland
        fi
        ;;
    *)
        logMessage "error" "No package provided for installation."
        ;;
    esac

    logMessage "info" "Successfully installed ${gpuDriver} and dependencies."
}

configureMkinitcpio() {
    local config="/etc/mkinitcpio.conf"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    logMessage "info" "Cleaning up ${config}..."
    sudo sed -i '/^#/d;/^$/d' "${config}"

    sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "${config}"

    logMessage "info" "Cleaning up brackets..."
    sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "${config}"

    logMessage "info" "Adding NVIDIA modules..."
    if [[ ${gpuDriver} == "nvidia-340xx-dkms" ]]; then
        sudo sed -i 's/^MODULES=(\([^)]*\))/MODULES=(\1 nvidia nvidia_uvm)/' "${config}"
    else
        sudo sed -i 's/^MODULES=(\([^)]*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${config}"
    fi

    logMessage "info" "Cleaning up brackets..."
    sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "${config}"

    logMessage "info" "Removing kms hook..."
    sudo sed -i 's/\bkms \b//g' "${config}"

    logMessage "info" "Configured ${config}."
}

configureModprobe() {
    local config="/etc/modprobe.d/nvidia.conf"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee "${config}" >/dev/null
    logMessage "info" "Configured ${config}."
}

configureGrubDefault() {
    local config="/etc/default/grub"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    sudo sed -i 's/nvidia_drm\.modeset=1//g' "${config}"

    logMessage "info" "Adding NVIDIA modeset to ${config}..."
    sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/!b;/nvidia_drm.modeset=1/!s/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 nvidia_drm.modeset=1/' "${config}"
    logMessage "info" "Configured ${config}."
}

regenerateInitramfs() {
    logMessage "info" "Regenerating initramfs... (this may take a while)"
    sudo mkinitcpio -P || logMessage "error" "Failed to regenerate the initramfs."
    logMessage "info" "Regernerated initramfs."
}

updateGrubConfig() {
    local config="/boot/grub/grub.cfg"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    sudo grub-mkconfig -o "${config}" || logMessage "error" "Failed to update ${config}."
    logMessage "info" "Configured ${config}"
}

confirmReboot() {
    echo -e ""
    echo -e "${green}Action complete.${reset}"
    read -rp "Would you like to reboot now? (y/N): " rebootNow
    case "${rebootNow}" in
    [yY][eE][sS] | [yY])
        sudo reboot now
        ;;
    *)
        logMessage "info" "Please reboot your system later to apply changes."
        echo -e ""
        echo -e "\t${green}Press any button to return${reset}"

        read -rsn1 option

        case "${option}" in
        *) ;;
        esac
        ;;
    esac
}

confirmUninstallation() {
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     This script will ${red}uninstall${reset} NVIDIA    │"
    echo -e "\t│  /  #  \    drivers and modify system            │"
    echo -e "\t│ /_______\   configurations.                      │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [!] Proceed with caution!                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    read -rp "Do you want to uninstall ${installedDriver}? (y/N): " confirm
    case "${confirm}" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Uninstalling ${installedDriver}...${reset}"
        uninstallationSteps
        ;;
    *)
        exitScript "Uninstallation cancelled."
        ;;
    esac
}

uninstallationSteps() {
    removeNvidiaPackages
    removeMkinitcpio
    removeModprobe
    removeGrubDefault
    regenerateInitramfs
    updateGrubConfig
    confirmReboot
}

removeNvidiaPackages() {
    logMessage "info" "Uninstalling ${installedDriver}..."

    case "${installedDriver}" in
    "nvidia")
        sudo pacman -R --noconfirm nvidia
        ;;
    "nvidia-open-dkms")
        sudo pacman -R --noconfirm nvidia-open-dkms
        ;;
    "nvidia-580xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperUninstall "nvidia-580xx-dkms"
        else
            checkChaoticAur
            sudo pacman -R --noconfirm nvidia-580xx-dkms
        fi
        ;;
    "nvidia-470xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperUninstall "nvidia-470xx-dkms"
        else
            checkChaoticAur
            sudo pacman -R --noconfirm nvidia-470xx-dkms
        fi
        ;;
    "nvidia-390xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperUninstall "nvidia-390xx-dkms"
        else
            checkChaoticAur
            sudo pacman -R --noconfirm nvidia-390xx-dkms
        fi
        ;;
    "nvidia-340xx-dkms")
        if [[ "${_nv_legacy_mode}" == "true" ]]; then
            checkAurHelper
            aurHelperUninstall "nvidia-340xx-dkms"
        else
            checkChaoticAur
            sudo pacman -R --noconfirm nvidia-340xx-dkms
        fi
        ;;
    *)
        logMessage "error" "No package provided for uninstallation."
        ;;
    esac

    logMessage "info" "Successfully uninstalled ${installedDriver}."
}

removeMkinitcpio() {
    local config="/etc/mkinitcpio.conf"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    logMessage "info" "Cleaning up ${config} structure..."
    sudo sed -i '/^#/d;/^$/d' "${config}"

    logMessage "info" "Removing NVIDIA modules..."
    sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "${config}"

    sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "${config}"

    sudo sed -i 's/\bkms \b//g' "${config}"

    logMessage "info" "Adding kms hook..."
    sudo sed -i 's/modconf/& kms/' "${config}"

    logMessage "info" "Configured ${config}."
}

removeModprobe() {
    local config="/etc/modprobe.d/nvidia.conf"
    backupConfig "${config}"
    logMessage "info" "Deleting ${config}..."

    sudo rm -f "${config}" || logMessage "warning" "Failed to delete NVIDIA modprobe file."
    logMessage "info" "Deleted ${config}."
}

removeGrubDefault() {
    local config="/etc/default/grub"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    sudo sed -i 's/nvidia_drm\.modeset=1//g' "${config}"
    logMessage "info" "Configured ${config}."
}

exitScript() {
    local message="$1"
    echo -e ""
    echo -e "${red}${message}${reset}"
    exit 0
}

install_nvidia_drivers() {
  echo
  read -rp "$(echo -e "${YELLOW}?${NC}  Install NVIDIA Drivers? [y/N] ")" ans
  [[ "${ans,,}" != "y" ]] && return

  info "Launching NVIDIA driver installer…"
  # Run in a subshell so internal exit calls don't terminate install.sh
  (
    trap 'exitScript "Aborted!"' SIGINT
    checkNvidia
    checkInstalledDriver
    showMenu
  ) || warn "NVIDIA installer exited with an error — you can rerun it separately."
  success "NVIDIA driver installer finished"
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
  install_nvidia_drivers
  install_spotify
  install_sddm_theme

  echo
  echo -e "${GREEN}${BOLD}All done!${NC}"
  echo -e "  • Log out and select Hyprland from your display manager to start."
  echo -e "  • Place your wallpaper at ${BOLD}~/Pictures/Wallpaper/wallpaper.png${NC}."
  echo -e "  • Any previous configs were backed up with a ${BOLD}.bak.TIMESTAMP${NC} suffix."
}

main "$@"
