#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# Cross-distro zsh + powerlevel10k + fzf + Kitty
# with Windows-style copy/paste and smart history
# Supports Debian/Ubuntu/Mint, Arch/Manjaro, Fedora/RHEL family
# ===============================================

# ---------- detect distro family ----------
if [ -r /etc/os-release ]; then . /etc/os-release; else echo "Cannot detect distro. /etc/os-release missing." >&2; exit 1; fi

family=""
case "${ID_LIKE:-$ID}" in
  *debian*|*ubuntu*|*linuxmint*|*lmde*)        family="apt" ;;
  *arch*|*manjaro*|*endeavouros*|*arco*|*artix*) family="pacman" ;;
  *fedora*|*rhel*|*centos*|*rocky*|*alma*)     family="dnf" ;;
esac
[ -n "$family" ] || { echo "Unsupported distro family. Need Debian/Arch/Fedora derivative."; exit 1; }

# ---------- sanity ----------
command -v sudo >/dev/null || { echo "This script needs sudo."; exit 1; }

# ---------- packages ----------
# Keep names exact per family
apt_pkgs=(zsh git curl unzip fontconfig fzf ripgrep bat fd-find zoxide zsh-autosuggestions zsh-syntax-highlighting kitty)
pacman_pkgs=(zsh git curl unzip fontconfig fzf ripgrep bat fd zoxide zsh-autosuggestions zsh-syntax-highlighting kitty)
dnf_pkgs=(zsh git curl unzip fontconfig fzf ripgrep bat fd-find zoxide zsh-autosuggestions zsh-syntax-highlighting kitty)

case "$family" in
  apt)
    sudo apt update
    sudo apt install -y "${apt_pkgs[@]}"
    ;;
  pacman)
    sudo pacman -Sy --noconfirm --needed "${pacman_pkgs[@]}"
    ;;
  dnf)
    sudo dnf -y install "${dnf_pkgs[@]}"
    ;;
esac

# ---------- Debian/Ubuntu quirks ----------
mkdir -p "$HOME/.local/bin"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; fi
export PATH="$HOME/.local/bin:$PATH"

# ---------- Nerd Font (Meslo Nerd) ----------
mkdir -p "$HOME/.local/share/fonts"
cd "$HOME/.local/share/fonts"
curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip
unzip -o Meslo.zip >/dev/null
fc-cache -fv >/dev/null
cd - >/dev/null

# ---------- powerlevel10k ----------
[ -d "$HOME/.p10k" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.p10k"

# ---------- find fzf keybindings path (varies by distro) ----------
FZF_BINDINGS=""
for candidate in \
  /usr/share/doc/fzf/examples/key-bindings.zsh \
  /usr/share/fzf/key-bindings.zsh \
  /usr/share/fzf/shell/key-bindings.zsh
do
  [ -f "$candidate" ] && FZF_BINDINGS="$candidate" && break
done

# ---------- write .zshrc ----------
ZSHRC="$HOME/.zshrc"
cp -f "$ZSHRC" "$ZSHRC.bak.$(date +%s)" 2>/dev/null || true

cat > "$ZSHRC" <<'ZRC'
# ===== PATH fixes for Debian names =====
export PATH="$HOME/.local/bin:$PATH"

# ===== history: useful, shared, not dumb =====
HISTFILE="$HOME/.zsh_history"
HISTSIZE=500000
SAVEHIST=500000
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS HIST_REDUCE_BLANKS HIST_VERIFY
setopt INC_APPEND_HISTORY SHARE_HISTORY EXTENDED_HISTORY

# ===== completion: fast and not annoying =====
autoload -U compinit; compinit -u
zmodload zsh/complist
setopt MENU_COMPLETE AUTO_MENU COMPLETE_IN_WORD
# case-insensitive, smart separators
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*'
# show descriptions and group results
zstyle ':completion:*' verbose yes
zstyle ':completion:*' group-name ''
# colorize completion using LS_COLORS
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# ===== quality-of-life =====
setopt AUTO_CD AUTO_PUSHD PUSHD_SILENT PUSHD_IGNORE_DUPS
setopt EXTENDED_GLOB
bindkey -e

# Make word boundaries sane for paths/flags: keep _ in words; treat /. - as separators
WORDCHARS='*?[]~=&;!#$%^(){}<>'

# ===== plugins =====
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ===== fzf (Ctrl-R history, Ctrl-T files) =====
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
elif [ -f /usr/share/fzf/key-bindings.zsh ]; then
  source /usr/share/fzf/key-bindings.zsh
elif [ -f /usr/share/fzf/shell/key-bindings.zsh ]; then
  source /usr/share/fzf/shell/key-bindings.zsh
fi
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# ===== zoxide (better cd) =====
eval "$(zoxide init zsh)"

# ===== modern defaults =====
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto -F'
elif command -v exa >/dev/null 2>&1; then
  alias ls='exa --group-directories-first --icons -F'
else
  alias ls='ls --color=auto -F'
fi
alias grep='rg --hidden --smart-case'

# ===== prompt =====
source "$HOME/.p10k/powerlevel10k.zsh-theme"
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# ===== keybindings that should be default =====
# Up/Down: prefix-aware history search (built-ins, no autoload drama)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Home/End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Word-wise navigation across common escape sequences
bindkey '^[\[1;5D' backward-word   # Ctrl+Left
bindkey '^[\[1;5C' forward-word    # Ctrl+Right
bindkey '^[b'      backward-word   # Alt+b fallback
bindkey '^[f'      forward-word    # Alt+f fallback
bindkey '^[\[1;3D' backward-word   # Alt+Left
bindkey '^[\[1;3C' forward-word    # Alt+Right

# Kill words like modern editors
bindkey '^[d'      kill-word                 # Alt+d
bindkey '^H'       backward-kill-word        # Ctrl+Backspace (common)
bindkey '^?'       backward-kill-word        # Backspace-as-DEL variant
bindkey '^[\[3;5~' kill-word                 # Ctrl+Delete
bindkey '^[\[3~'   delete-char               # Delete

# Yank (paste) convenience
bindkey '^Y' yank
ZRC

# ---------- make zsh default ----------
if [ "$SHELL" != "$(command -v zsh)" ]; then chsh -s "$(command -v zsh)"; fi

# ---------- Kitty config: Windows-style ergonomics, pretty, dark ----------
mkdir -p "$HOME/.config/kitty"
cat > "$HOME/.config/kitty/kitty.conf" <<'KCFG'
# Font
font_family      MesloLGS Nerd Font
font_size        13.0
bold_font        auto
italic_font      auto
bold_italic_font auto

# Window & aesthetics
hide_window_decorations no
window_padding_width 10
background_opacity 0.9
cursor_shape beam
enable_audio_bell no
copy_on_select yes
strip_trailing_spaces smart
mouse_hide_wait_interval 0.5

# Right-click paste, middle-click primary selection
paste_on_middle_click yes
map right_click paste_from_clipboard

# Ctrl+V pastes; Ctrl+C copies selection or sends SIGINT if none
map ctrl+v paste_from_clipboard
map ctrl+shift+v paste_from_selection
map ctrl+c copy_or_interrupt

# Tabs
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

# ---------- fzf bind notice (optional info only) ----------
if [ -n "$FZF_BINDINGS" ]; then
  echo "fzf key bindings sourced from: $FZF_BINDINGS"
fi

echo
echo "Done. Start a new Kitty or run: exec zsh"
echo "• First zsh run opens Powerlevel10k wizard (choose lean/classic)."
echo "• Up/Down do prefix history. Ctrl+Left/Right move by words. Ctrl+Backspace/Ctrl+Delete kill words."
