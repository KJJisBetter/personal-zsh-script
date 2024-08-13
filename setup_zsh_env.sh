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

# Determine the package manager
if command -v brew &> /dev/null; then
    PKG_MANAGER="brew"
elif command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
else
    echo "No supported package manager found. Will attempt manual installation for some packages."
    PKG_MANAGER="manual"
fi

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
    local command_name="$2"
    if ! command -v "$command_name" &> /dev/null; then
        echo "Installing $package..."
        case "$PKG_MANAGER" in
            apt-get)
                sudo $PKG_MANAGER update && sudo $PKG_MANAGER install -y "$package"
                ;;
            dnf|yum)
                sudo $PKG_MANAGER install -y "$package"
                ;;
            *)
                echo "Please install $package manually."
                ;;
        esac
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
    ZOXIDE_INSTALL_SCRIPT="$CORRECT_HOME/zoxide_install.sh"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o "$ZOXIDE_INSTALL_SCRIPT"
    chmod +x "$ZOXIDE_INSTALL_SCRIPT"
    chown "$CORRECT_USER:$CORRECT_USER" "$ZOXIDE_INSTALL_SCRIPT"
    
    # Modify the install script to use the correct installation directory
    sed -i 's|PREFIX=.*|PREFIX="$HOME/.local"|' "$ZOXIDE_INSTALL_SCRIPT"
    
    # Run the install script as the correct user
    sh -c "HOME=$CORRECT_HOME $ZOXIDE_INSTALL_SCRIPT"
    
    # Clean up
    rm "$ZOXIDE_INSTALL_SCRIPT"
    
    echo "zoxide installed successfully."
else
    echo "zoxide is already installed."
fi

# Install Oh My Posh
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    check_and_create_dir $CORRECT_HOME/.local/bin
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

# Install fd-find
case "$PKG_MANAGER" in
    apt-get)
        install_if_not_installed fd-find
        ;;
    dnf|yum)
        install_if_not_installed fd-find
        ;;
    *)
        echo "Please install fd-find manually."
        ;;
esac

# Install bat
install_if_not_installed bat

# Create symlinks if needed
if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
    sudo ln -s $(which fdfind) /usr/local/bin/fd
fi

if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
    sudo ln -s $(which batcat) /usr/local/bin/bat
fi

# Ensure correct ownership of user directories
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local"
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.config"

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

install_eza() {
    if ! command -v eza &> /dev/null; then
        echo "Installing eza..."
        
        # Determine system architecture
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64)
                EZA_ARCH="x86_64-unknown-linux-gnu"
                ;;
            aarch64)
                EZA_ARCH="aarch64-unknown-linux-gnu"
                ;;
            *)
                echo "Unsupported architecture: $ARCH"
                return 1
                ;;
        esac

        # Download and install eza
        TEMP_DIR=$(mktemp -d)
        wget -c "https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_ARCH}.tar.gz" -O - | tar xz -C "$TEMP_DIR"
        chmod +x "$TEMP_DIR/eza"
        chown root:root "$TEMP_DIR/eza"
        mv "$TEMP_DIR/eza" /usr/local/bin/eza
        rm -rf "$TEMP_DIR"

        # Create symlink for exa compatibility
        if command -v exa &> /dev/null; then
            echo "Replacing exa with eza..."
            rm -f /usr/local/bin/exa
            ln -s /usr/local/bin/eza /usr/local/bin/exa
        fi

        echo "eza installed successfully."
    else
        echo "eza is already installed."
    fi
}

# Call the function to install eza
install_eza

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
export PATH="/.local/bin:$PATH"

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
