<div align="center">

<img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/logos/exports/1544x1544_circle.png" width="100" />

# hyprland-dots

**A cozy Catppuccin Mocha Hyprland configuration**

![Hyprland](https://img.shields.io/badge/Hyprland-89b4fa?style=for-the-badge&logo=linux&logoColor=1e1e2e)
![Catppuccin](https://img.shields.io/badge/Catppuccin-Mocha-cba6f7?style=for-the-badge&logoColor=1e1e2e)
![Arch](https://img.shields.io/badge/Arch-Linux-89dceb?style=for-the-badge&logo=arch-linux&logoColor=1e1e2e)

</div>

---

## Palette

| Label | Hex | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; |
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
| Compositor | Hyprland |
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
| Multiplexer | tmux (Catppuccin plugin) |
| Font | Fira Code |

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

**Prerequisites**

```bash
# Core
hyprland waybar rofi kitty zsh

# Utilities
fastfetch btop cava yazi swappy udiskie swaync awww nm-applet

# Optional
spicetify tmux neovim
```

**Deploy**

```bash
git clone https://github.com/yourusername/hyprland-dots ~/Desktop/hyprland-dots
cd ~/Desktop/hyprland-dots

# Copy configs
cp -r .config/* ~/.config/
cp .tmux.conf ~/
cp .zshrc ~/
```

> Replace wallpaper at `~/Pictures/Wallpaper/wallpaper.png` to match the expected path in `hyprland.conf`.

---

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

<div align="center">

Made with the Catppuccin Mocha palette — soothing pastels for the high-spirited.

</div>
