<div align="center">

<img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/logos/exports/1544x1544_circle.png" width="100" />

# hyprland-dots

**A cozy Catppuccin Mocha Hyprland configuration made for archlinux**

![Hyprland](https://img.shields.io/badge/Hyprland-89b4fa?style=for-the-badge&logo=linux&logoColor=1e1e2e)
![Catppuccin](https://img.shields.io/badge/Catppuccin-Mocha-cba6f7?style=for-the-badge&logoColor=1e1e2e)
![Arch](https://img.shields.io/badge/Arch-Linux-89dceb?style=for-the-badge&logo=arch-linux&logoColor=1e1e2e)

</div>

---

## Palette

| Label | Hex | Color &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; |
|---|---|---|
| Base | `#1e1e2e` | ![#1e1e2e](https://via.placeholder.com/20/1e1e2e/1e1e2e.png) |
| Mantle | `#181825` | ![#181825](https://via.placeholder.com/20/181825/181825.png) |
| Surface 0 | `#313244` | ![#313244](https://via.placeholder.com/20/313244/313244.png) |
| Text | `#cdd6f4` | ![#cdd6f4](https://via.placeholder.com/20/cdd6f4/cdd6f4.png) |
| Blue | `#89b4fa` | ![#89b4fa](https://via.placeholder.com/20/89b4fa/89b4fa.png) |
| Mauve | `#cba6f7` | ![#cba6f7](https://via.placeholder.com/20/cba6f7/cba6f7.png) |
| Rosewater | `#f5e0dc` | ![#f5e0dc](https://via.placeholder.com/20/f5e0dc/f5e0dc.png) |

---

## Stack

| Role | App |
|---|---|
| WM | Hyprland |
| Terminal | Kitty |
| Shell | Zsh + oh-my-zsh |
| Bar | Waybar |
| Launcher | Rofi |
| Notifications | SwayNC |
| File Manager | Yazi (in Kitty) |
| Editor | Neovim (LazyVim) |
| System Info | Fastfetch |
| System Monitor | btop |
| Audio Visualizer | CAVA |
| Screenshot | Swappy |
| Wallpaper | awww |
| Spotify | Spicetify (Catppuccin) |
| Terminal Multiplexer | tmux (Catppuccin plugin) |
| Font | Fira Code |
| Display Manager | SDDM (sddm-astronaut-theme) |

---

## Hyprland Details

- **Layout:** Dwindle
- **Gaps:** `in = 1.5` / `out = 8`
- **Border:** blue `#89b4fa` (active) — base `#1e1e2e` (inactive)
- **Rounding:** 10px
- **Blur:** enabled (size 5, 3 passes)
- **Opacity:** 0.9 across windows
- **Animations:** Minimal slide with wind bezier curves

---

## Waybar Modules

```
[workspaces] [music]        [clock]        [backlight | memory | pomodoro | bluetooth | network | audio | cpu | battery]
```

---

## Installation

> These are personal dotfiles — install selectively, not blindly.

**Use the install.sh**

```bash
git clone https://github.com/tame-t/hyprland-dots
cd ~/hyprland-dots
chmod +x install.sh
./install.sh
```

---

## Manual installation

**Install yay**

  The repo for yay https://github.com/jguer/yay

```bash
# you need to install yay AUR helper to install the packages below
sudo pacman -Syu && sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```
**Prerequisites**

```bash
# Core
hyprland waybar rofi kitty zsh

# Utilities
fastfetch btop cava yazi swappy udiskie swaync awww nm-applet

# Optional
spicetify tmux neovim

# Install command
yay -Syu && yay -S hyprland waybar rofi kitty zsh \
fastfetch btop cava yazi swappy udiskie swaync awww nm-applet \
spicetify tmux neovim
```

**Package to install**
```bash
  yay -Syu && yay -S hyprland waybar rofi-wayland kitty zsh oh-my-zsh-git zsh-autosuggestions \
    fastfetch btop cava yazi swappy grim slurp wl-clipboard \
    awww swaync udiskie network-manager-applet \
    networkmanager bluez bluez-utils \
    pipewire wireplumber pipewire-pulse pavucontrol brightnessctl \
    neovim tmux obs-studio nwg-look \
    ttf-fira-code nerd-fonts-fira-code \
    xdg-desktop-portal-hyprland xdg-user-dirs
```

**If you want spotify**
```bash
yay -S spicetify-cli spotify
```

**Install**

```bash
git clone https://github.com/yourusername/hyprland-dots ~/Desktop/hyprland-dots
cd ~/Desktop/hyprland-dots

# Copy configs
cp -r .config/* ~/.config/
cp .tmux.conf ~/
cp .zshrc ~/
cp .gtkrc-2.0 ~/
```

> Replace wallpaper at `~/Pictures/Wallpaper/wallpaper.png` to match the expected path in `hyprland.conf`.

---
## If you pc broken call teha

## Uninstall

```bash
git clone https://github.com/tame-t/hyprland-dots
cd ~/hyprland-dots
chmod +x uninstall.sh
./uninstall.sh
```

**Fulluninstall**
```bash
git clone https://github.com/tame-t/hyprland-dots
cd ~/hyprland-dots
chmod +x fulluninstall.sh
./fulluninstall.sh
```

## Shell

Zsh is configured with:

- **Theme:** `bira` (oh-my-zsh)
- **Plugin:** `zsh-autosuggestions`
- **Startup:** Fastfetch on every new terminal
- **Editor:** Neovim (`$EDITOR=nvim`)
- **Alias:** `allfetch` — runs the full fastfetch layout

---

## Font

[Fira Code](https://github.com/tonsky/FiraCode) is used across the terminal and editor. Install it from your distro's package manager or Nerd Fonts.

---

## Credits
- **[catppuccin-mocha](https://github.com/catppuccin/catppuccin)** by [catppuccin](https://github.com/catppuccin) - the color palette and many configs for this dot files.
- **[sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme)** by [Keyitdev](https://github.com/Keyitdev) — the SDDM login theme used by the optional installer.
- **[yay](https://github.com/jguer/yay)** by [Jguer](https://github.com/Jguer) - the AUR helper that was used in the install.sh.
---

<div align="center">

Made with the Catppuccin Mocha palette — soothing pastels for the high-spirited.

</div>
