#!/bin/bash

set -ex

# Determine the correct user and home directory
if [ -n "$CODER_USER_NAME" ]; then
    CORRECT_USER="$CODER_USER_NAME"
elif [ -n "$SUDO_USER" ]; then
    CORRECT_USER="$SUDO_USER"
else
    CORRECT_USER="$(whoami)"
fi

CORRECT_HOME="/home/$CORRECT_USER"

# Function to run commands as the correct user
run_as_user() {
    if [ "$(whoami)" = "$CORRECT_USER" ]; then
        "$@"
    else
        sudo -H -u "$CORRECT_USER" "$@"
    fi
}

echo "Setting up environment for user: $CORRECT_USER"
echo "Home directory: $CORRECT_HOME"

# Function to check and create a directory if it doesn't exist
check_and_create_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        run_as_user mkdir -p "$dir_path"
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
        sudo apt update && sudo apt-get install -y "$package"
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
    run_as_user curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | run_as_user bash
fi

# Install Oh My Posh if not already installed
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    run_as_user curl -s https://ohmyposh.dev/install.sh | run_as_user bash -s -- -d "$CORRECT_HOME/.local/bin"
fi

# Create themes directory and download Zen theme for Oh My Posh
THEMES_DIR="$CORRECT_HOME/.config/oh-my-posh/themes"
check_and_create_dir "$THEMES_DIR"

ZEN_THEME_URL="https://raw.githubusercontent.com/dreamsofautonomy/zen-omp/main/zen.toml"
ZEN_THEME_PATH="$THEMES_DIR/zen.toml"
if [ ! -f "$ZEN_THEME_PATH" ]; then
    echo "Downloading Zen theme for Oh My Posh..."
    run_as_user curl -o "$ZEN_THEME_PATH" "$ZEN_THEME_URL"
else
    echo "Zen theme already exists at $ZEN_THEME_PATH"
fi

# Install fd-find if not installed and create symlink
if ! command -v fd &> /dev/null; then
    install_if_not_installed fd-find
    run_as_user ln -sf $(which fdfind) "$CORRECT_HOME/.local/bin/fd"
fi

# Install bat and create symlink to batcat if not installed
if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
    install_if_not_installed bat
    run_as_user ln -sf $(which batcat) "$CORRECT_HOME/.local/bin/bat"
fi

# Install eza if not already installed
if ! command -v eza &> /dev/null; then
    echo "Installing eza..."
    sudo mkdir -p /etc/apt/keyrings
    sudo wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
fi

# Install fzf if not already installed
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    run_as_user git clone --depth 1 https://github.com/junegunn/fzf.git "$CORRECT_HOME/.fzf"
    run_as_user "$CORRECT_HOME/.fzf/install" --all
fi

# Install Zinit if not already installed
ZINIT_HOME="${XDG_DATA_HOME:-${CORRECT_HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    run_as_user mkdir -p "$(dirname "$ZINIT_HOME")"
    run_as_user git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Clone fzf-git script
FZF_GIT_DIR="$CORRECT_HOME/.fzf-git"
if [ ! -d "$FZF_GIT_DIR" ]; then
    run_as_user git clone https://github.com/junegunn/fzf-git.sh.git "$FZF_GIT_DIR"
fi

# Ensure .zshrc exists and has correct permissions
ZSHRC="$CORRECT_HOME/.zshrc"
run_as_user touch "$ZSHRC"
run_as_user chmod 644 "$ZSHRC"

# Function to safely append configurations to .zshrc
append_to_zshrc() {
    local content="$1"
    run_as_user tee -a "$ZSHRC" > /dev/null << EOF
$content
EOF
}

# Content to add to .zshrc
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

# Append the content to .zshrc
append_to_zshrc "$zshrc_content"

# Ensure correct ownership of user directories
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local"
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.config"
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf"
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf-git"
sudo chown "$CORRECT_USER:$CORRECT_USER" "$ZSHRC"

echo "Zsh configuration completed for user $CORRECT_USER. Please restart your terminal or source your .zshrc file."
