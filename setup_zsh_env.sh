#!/bin/bash

# Function to check and create a directory if it doesn't exist
check_and_create_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        echo "Created directory at $dir_path"
    else
        echo "Directory $dir_path already exists."
    fi
}

# Function to install a package if it's not already installed
install_if_not_installed() {
    local package="$1"
    if ! command -v "$package" &> /dev/null; then
        echo "Installing $package..."
        sudo apt update && sudo apt install -y "$package"
    else
        echo "$package is already installed."
    fi
}

# Function to add a path to .zshrc if not already added
add_to_zshrc_if_not_exists() {
    local entry="$1"
    if ! grep -qF "$entry" ~/.zshrc; then
        echo "$entry" >> ~/.zshrc
        echo "Added to .zshrc: $entry"
    fi
}

# Install zsh if not already installed
install_if_not_installed zsh

# Install unzip if not already installed
install_if_not_installed unzip

# Install zoxide if not already installed
if ! command -v zoxide &> /dev/null; then
    echo "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

# Ensure zoxide is initialized in .zshrc
add_to_zshrc_if_not_exists 'eval "$(zoxide init zsh)"'

# Ensure the alias for cd to z is in .zshrc
add_to_zshrc_if_not_exists 'alias cd="z"'

# Install Oh My Posh if not already installed
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
fi

# Add Oh My Posh initialization to .zshrc
add_to_zshrc_if_not_exists 'eval "$(oh-my-posh init zsh --config ~/.zsh-stuff/themes/zen.toml)"'

# Create themes directory and download Zen theme for Oh My Posh
THEMES_DIR="$HOME/.zsh-stuff/themes"
check_and_create_dir "$THEMES_DIR"

ZEN_THEME_URL="https://raw.githubusercontent.com/dreamsofautonomy/zen-omp/main/zen.toml"
ZEN_THEME_PATH="$THEMES_DIR/zen.toml"
if [ ! -f "$ZEN_THEME_PATH" ]; then
    echo "Downloading Zen theme for Oh My Posh..."
    curl -o "$ZEN_THEME_PATH" "$ZEN_THEME_URL"
else
    echo "Zen theme already exists at $ZEN_THEME_PATH"
fi

# Install fd-find if not installed and create symlink
if ! command -v fd &> /dev/null; then
    install_if_not_installed fd-find
    ln -sf $(which fdfind) ~/.local/bin/fd
fi

# Install bat and create symlink to batcat if not installed
if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
    install_if_not_installed bat
    ln -sf $(which batcat) ~/.local/bin/bat
fi

# Install eza if not already installed
install_if_not_installed eza

# Install Zinit if not already installed
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Add configurations to .zshrc
cat << 'EOF' >> ~/.zshrc

# Paths and aliases
export PATH="/usr/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share:$PATH"
export PATH=$PATH:/path/to/python
export PATH=$PATH:/usr/bin/python3

alias ls="eza --icons=always"

# Load Zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ -d "$ZINIT_HOME" ]; then
    source "${ZINIT_HOME}/zinit.zsh"
    zinit light zsh-users/zsh-syntax-highlighting
    zinit light zsh-users/zsh-completions
    zinit light zsh-users/zsh-autosuggestions
    zinit light Aloxaf/fzf-tab
    zinit snippet OMZP::git
    zinit snippet OMZP::sudo
    zinit snippet OMZP::archlinux
    zinit snippet OMZP::aws
    zinit snippet OMZP::kubectl
    zinit snippet OMZP::kubectx
    zinit snippet OMZP::command-not-found
    zinit cdreplay -q
fi

# Load completions
autoload -Uz compinit && compinit

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History settings
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Fzf configuration
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd for fzf completion
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# Set fzf options
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced fzf customization
_fzf_comprun() {
  local command=$1
  shift
  case "$command" in
    cd) fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo $'{}" "$@" ;;
    ssh) fzf --preview 'dig {}' "$@" ;;
    *) fzf --preview "bat -n --color=always --line-range :500 {}" "$@" ;;
  esac
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Initialize zoxide and Oh My Posh
eval "$(zoxide init zsh)"
eval "$(oh-my-posh init zsh --config ~/.zsh-stuff/themes/zen.toml)"
EOF

echo "Setup completed. Please restart your terminal or source your .zshrc file."

