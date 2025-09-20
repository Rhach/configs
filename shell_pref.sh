#!/usr/bin/env bash
set -euo pipefail

# ---------- detect distro family ----------
if [ -r /etc/os-release ]; then
  . /etc/os-release
else
  echo "Cannot detect distro. /etc/os-release missing." >&2
  exit 1
fi

family=""
case "${ID_LIKE:-$ID}" in
  *debian*|*ubuntu*|*linuxmint*|*lmde*) family="apt" ;;
  *arch*|*manjaro*|*endeavouros*) family="pacman" ;;
  *fedora*|*rhel*|*centos*|*rocky*|*almalinux*) family="dnf" ;;
esac

if [ -z "$family" ]; then
  echo "Unsupported distro family. Expected Debian/Arch/Fedora derivative." >&2
  exit 1
fi

# ---------- sanity ----------
if ! command -v sudo >/dev/null 2>&1; then
  echo "This script needs sudo." >&2
  exit 1
fi

# ---------- packages ----------
apt_pkgs=(zsh git curl unzip fontconfig fzf ripgrep bat fd-find zoxide zsh-autosuggestions zsh-syntax-highlighting kitty)
pacman_pkgs=(zsh git curl unzip fontconfig fzf ripgrep bat fd zoxide zsh-autosuggestions zsh-syntax-highlighting kitty)
dnf_pkgs=(zsh git curl unzip fontconfig fzf ripgrep bat fd-find zoxide zsh-autosuggestions zsh-syntax-highlighting kitty)

case "$family" in
  apt)
    sudo apt update
    sudo apt install -y "${apt_pkgs[@]}"
    ;;
  pacman)
    sudo pacman -Sy --noconfirm "${pacman_pkgs[@]}"
    ;;
  dnf)
    sudo dnf -y install "${dnf_pkgs[@]}"
    ;;
esac

# ---------- Debian/Ubuntu quirks (names) ----------
mkdir -p "$HOME/.local/bin"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi
export PATH="$HOME/.local/bin:$PATH"

# ---------- Nerd Font ----------
mkdir -p "$HOME/.local/share/fonts"
cd "$HOME/.local/share/fonts"
curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip
unzip -o Meslo.zip >/dev/null
fc-cache -fv >/dev/null
cd - >/dev/null

# ---------- powerlevel10k ----------
if [ ! -d "$HOME/.p10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.p10k"
fi

# ---------- fzf examples path ----------
FZF_BINDINGS=""
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  FZF_BINDINGS=/usr/share/doc/fzf/examples/key-bindings.zsh
elif [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
  FZF_BINDINGS=/usr/share/doc/fzf/examples/key-bindings.bash
fi

# ---------- .zshrc ----------
ZSHRC="$HOME/.zshrc"
cp -f "$ZSHRC" "$ZSHRC.bak.$(date +%s)" 2>/dev/null || true
cat > "$ZSHRC" <<"ZRC"
# PATH fixes
export PATH="$HOME/.local/bin:$PATH"

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=500000
SAVEHIST=500000
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS HIST_REDUCE_BLANKS HIST_VERIFY
setopt INC_APPEND_HISTORY SHARE_HISTORY

# completion
autoload -U compinit; compinit -u
zmodload zsh/complist
setopt MENU_COMPLETE AUTO_MENU

# qol
setopt AUTO_CD AUTO_PUSHD PUSHD_SILENT PUSHD_IGNORE_DUPS EXTENDED_GLOB
bindkey -e

# plugins
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# fzf
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
fi
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# zoxide
eval "$(zoxide init zsh)"

# modern defaults
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto -F'
elif command -v exa >/dev/null 2>&1; then
  alias ls='exa --group-directories-first --icons -F'
else
  alias ls='ls --color=auto -F'
fi
alias grep='rg --hidden --smart-case'

# prompt
source "$HOME/.p10k/powerlevel10k.zsh-theme"
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# history substring search on arrows
autoload -U history-beginning-search-backward-end history-beginning-search-forward-end
zle -N history-beginning-search-backward-end
zle -N history-beginning-search-forward-end
bindkey "^[[A" history-beginning-search-backward-end
bindkey "^[[B" history-beginning-search-forward-end
ZRC

# ---------- make zsh default ----------
if [ "$SHELL" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

# ---------- Kitty config (Windows-like ergonomics) ----------
mkdir -p "$HOME/.config/kitty"
cat > "$HOME/.config/kitty/kitty.conf" <<"KCFG"
# font
font_family      MesloLGS Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        13.0

# window + aesthetics
hide_window_decorations no
window_padding_width 10
background_opacity 0.9
cursor_shape     beam
enable_audio_bell no
copy_on_select   yes
strip_trailing_spaces smart
mouse_hide_wait_interval 0.5

# Right-click paste, middle-click paste selection
paste_on_middle_click yes
map right_click paste_from_clipboard

# Ctrl+V paste, Ctrl+C copies if selection else SIGINT
map ctrl+v paste_from_clipboard
map ctrl+shift+v paste_from_selection
map ctrl+c copy_or_interrupt

# Tabs styling
tab_bar_style powerline
tab_powerline_style angled
tab_bar_min_tabs 2
active_tab_font_style bold
inactive_tab_font_style normal

# Dracula colors
background #282a36
foreground #f8f8f2
selection_background #44475a
color0 #21222c
color1 #ff5555
color2 #50fa7b
color3 #f1fa8c
color4 #bd93f9
color5 #ff79c6
color6 #8be9fd
color7 #f8f8f2
color8 #6272a4
color9 #ff6e6e
color10 #69ff94
color11 #ffffa5
color12 #d6acff
color13 #ff92df
color14 #a4ffff
color15 #ffffff
KCFG

echo
echo "Done. Start a new Kitty. First zsh run opens Powerlevel10k config."
