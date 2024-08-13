#!/bin/bash

set -ex

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
        apt update && apt-get install -y "$package"
    else
        echo "$package is already installed."
    fi
}

# Install zsh if not already installed
install_if_not_installed zsh

# Install unzip if not already installed
install_if_not_installed unzip

# Install zoxide if not already installed
if ! command -v zoxide &> /dev/null; then
    echo "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# Install Oh My Posh if not already installed
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
fi

# Create themes directory and download Zen theme for Oh My Posh
THEMES_DIR="$HOME/.config/oh-my-posh/themes"
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
    ln -sf $(which fdfind) "$HOME/.local/bin/fd"
fi

# Install bat and create symlink to batcat if not installed
if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
    install_if_not_installed bat
    ln -sf $(which batcat) "$HOME/.local/bin/bat"
fi

# Install eza if not already installed
if ! command -v eza &> /dev/null; then
    echo "Installing eza..."
    mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list
    apt update
    apt install -y eza
fi

# Install fzf if not already installed
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all
fi

# Install Zinit if not already installed
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Clone fzf-git script
FZF_GIT_DIR="$HOME/.fzf-git"
if [ ! -d "$FZF_GIT_DIR" ]; then
    git clone https://github.com/junegunn/fzf-git.sh.git "$FZF_GIT_DIR"
fi

# Ensure .zshrc exists and has correct permissions
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
chmod 644 "$ZSHRC"

# Function to safely append configurations to .zshrc
append_to_zshrc() {
    local content="$1"
    echo "$content" >> "$ZSHRC"
}

# Content to add to .zshrc
append_to_zshrc=$(cat << 'EOF'

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History
HISTSIZE=5000
HISTFILE=$HOME/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always {} | head -200'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --color=always {} | head -200'

# Aliases
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"

# PATHS
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.fzf/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/bin:$PATH"
export PATH="/bin:$PATH"

# FZF configuration
[ -f $HOME/.fzf.zsh ] && source $HOME/.fzf.zsh

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"

# FZF options
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Use fd for fzf completion
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# Source fzf-git script
source $HOME/.fzf-git/fzf-git.sh

# Shell integration
eval "$(zoxide init zsh)"

# oh my posh customization for zsh
eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/themes/zen.toml)"

EOF
)

# Ensure correct ownership of user directories
sudo chown -R $(whoami):$(whoami) "$HOME/.local"
sudo chown -R $(whoami):$(whoami) "$HOME/.config"
sudo chown -R $(whoami):$(whoami) "$HOME/.fzf"
sudo chown -R $(whoami):$(whoami) "$HOME/.fzf-git"

# Append the content to .zshrc
append_to_zshrc "$zshrc_content"

# Ensure correct ownership of .zshrc
chown $(whoami):$(whoami) "$ZSHRC"

echo "Zsh configuration completed. Please restart your terminal or source your .zshrc file."
