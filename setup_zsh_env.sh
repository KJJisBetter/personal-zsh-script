#!/bin/bash

set -ex

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Determine the correct user and home directory
if [ -n "$SUDO_USER" ]; then
    CORRECT_USER="$SUDO_USER"
else
    echo "This script must be run with sudo"
    exit 1
fi

CORRECT_HOME="/home/$CORRECT_USER"

echo "Setting up environment for user: $CORRECT_USER"
echo "Home directory: $CORRECT_HOME"

# Function to check and create a directory if it doesn't exist
check_and_create_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        chown "$CORRECT_USER:$CORRECT_USER" "$dir_path"
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

# Install zsh and unzip
install_if_not_installed zsh
install_if_not_installed unzip

# Install zoxide
if ! command -v zoxide &> /dev/null; then
    echo "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# Install Oh My Posh
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$CORRECT_HOME/.local/bin"
    chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local/bin"
fi

# Create themes directory and download Zen theme for Oh My Posh
THEMES_DIR="$CORRECT_HOME/.config/oh-my-posh/themes"
check_and_create_dir "$THEMES_DIR"

ZEN_THEME_URL="https://raw.githubusercontent.com/dreamsofautonomy/zen-omp/main/zen.toml"
ZEN_THEME_PATH="$THEMES_DIR/zen.toml"
if [ ! -f "$ZEN_THEME_PATH" ]; then
    echo "Downloading Zen theme for Oh My Posh..."
    curl -o "$ZEN_THEME_PATH" "$ZEN_THEME_URL"
    chown "$CORRECT_USER:$CORRECT_USER" "$ZEN_THEME_PATH"
else
    echo "Zen theme already exists at $ZEN_THEME_PATH"
fi

# Function to get the latest release URL for a given repo and file pattern
install_from_github() {
    local tool_name=$1
    local repo=$2
    local file_pattern=$3
    local binary_name=$4

    echo "Installing $tool_name..."
    TEMP_DIR=$(mktemp -d)
    DOWNLOAD_URL=$(get_latest_release_url "$repo" "$file_pattern")
    
    if [ -z "$DOWNLOAD_URL" ]; then
        echo "Failed to get $tool_name download URL. Please install manually."
        return 1
    fi

    echo "Downloading from: $DOWNLOAD_URL"
    wget --verbose --tries=3 --timeout=15 "$DOWNLOAD_URL" -O "$TEMP_DIR/$tool_name.tar.gz"
    if [ $? -ne 0 ]; then
        echo "Failed to download $tool_name. Please check your internet connection and try again."
        rm -rf "$TEMP_DIR"
        return 1
    fi

    echo "Extracting $tool_name..."
    tar xzvf "$TEMP_DIR/$tool_name.tar.gz" -C "$TEMP_DIR"
    if [ $? -ne 0 ]; then
        echo "Failed to extract $tool_name. The downloaded file may be corrupted."
        rm -rf "$TEMP_DIR"
        return 1
    fi

    echo "Moving $tool_name to /usr/local/bin/"
    mv "$TEMP_DIR/$binary_name" "/usr/local/bin/$tool_name"
    if [ $? -ne 0 ]; then
        echo "Failed to move $tool_name to /usr/local/bin/. Please check permissions."
        rm -rf "$TEMP_DIR"
        return 1
    fi

    rm -rf "$TEMP_DIR"
    echo "$tool_name installed successfully."
}

get_latest_release_url() {
    local repo=$1
    local file_pattern=$2
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    
    echo "Fetching latest release info from: $api_url"
    local release_info=$(curl -s "$api_url")
    if [ $? -ne 0 ]; then
        echo "Failed to fetch release information from GitHub API."
        return 1
    fi

    local download_url=$(echo "$release_info" | grep -oP '"browser_download_url": "\K(.*)(?=")' | grep "$file_pattern" | head -n 1)
    if [ -z "$download_url" ]; then
        echo "Failed to find a matching release asset."
        return 1
    fi

    echo "$download_url"
}

# Install fd-find
if ! command -v fd &> /dev/null; then
    install_from_github "fd" "sharkdp/fd" "fd-v.*-x86_64-unknown-linux-gnu.tar.gz" "fd"
fi

# Install bat
if ! command -v bat &> /dev/null; then
    install_from_github "bat" "sharkdp/bat" "bat-v.*-x86_64-unknown-linux-gnu.tar.gz" "bat"
fi

# Install eza
if ! command -v eza &> /dev/null; then
    install_from_github "eza" "eza-community/eza" "eza_x86_64-unknown-linux-musl.tar.gz" "eza"
fi

# Install fzf
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$CORRECT_HOME/.fzf"
    chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf"
    sudo -u "$CORRECT_USER" "$CORRECT_HOME/.fzf/install" --all
fi

# Install Zinit
ZINIT_HOME="${XDG_DATA_HOME:-${CORRECT_HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    chown -R "$CORRECT_USER:$CORRECT_USER" "$(dirname "$ZINIT_HOME")"
fi

# Clone fzf-git script
FZF_GIT_DIR="$CORRECT_HOME/.fzf-git"
if [ ! -d "$FZF_GIT_DIR" ]; then
    git clone https://github.com/junegunn/fzf-git.sh.git "$FZF_GIT_DIR"
    chown -R "$CORRECT_USER:$CORRECT_USER" "$FZF_GIT_DIR"
fi

# Ensure .zshrc exists and has correct permissions
ZSHRC="$CORRECT_HOME/.zshrc"
touch "$ZSHRC"
chown "$CORRECT_USER:$CORRECT_USER" "$ZSHRC"
chmod 644 "$ZSHRC"

# Function to safely append configurations to .zshrc
append_to_zshrc() {
    local content="$1"
    echo "$content" | sudo -u "$CORRECT_USER" tee -a "$ZSHRC" > /dev/null
}

# Add your zshrc content here
zshrc_content=$(cat << 'EOF'

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
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local"
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.config"
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf"
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf-git"
sudo chown "$CORRECT_USER:$CORRECT_USER" "$ZSHRC"

append_to_zshrc "$zshrc_content"

echo "Zsh configuration completed for user $CORRECT_USER. Please restart your terminal or source your .zshrc file."
