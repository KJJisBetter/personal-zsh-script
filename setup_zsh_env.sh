#!/bin/bash

# Remove 'set -e' to prevent the script from stopping on errors
# set -e

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

# Determine the package manager and run update/upgrade
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    echo "Updating and upgrading system packages..."
    sudo apt-get update && sudo apt-get upgrade -y
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    echo "Updating and upgrading system packages..."
    sudo dnf upgrade -y
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    echo "Updating and upgrading system packages..."
    sudo yum update -y
elif command -v brew &> /dev/null; then
    PKG_MANAGER="brew"
    echo "Updating Homebrew and upgrading packages..."
    brew update && brew upgrade
else
    echo "No supported package manager found. Skipping system update and upgrade."
    PKG_MANAGER="manual"
fi

# Function to check and create a directory if it doesn't exist
check_and_create_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path" || { echo "Failed to create directory $dir_path"; return 1; }
        chown "$CORRECT_USER:$CORRECT_USER" "$dir_path" || { echo "Failed to change ownership of $dir_path"; return 1; }
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
                sudo $PKG_MANAGER install -y "$package" || { echo "Failed to install $package"; return 1; }
                ;;
            dnf|yum)
                sudo $PKG_MANAGER install -y "$package" || { echo "Failed to install $package"; return 1; }
                ;;
            *)
                echo "Please install $package manually."
                ;;
        esac
    else
        echo "$package is already installed."
    fi
}

# Install git if not present
install_if_not_installed git || echo "Failed to install git"

# Install zsh and unzip
install_if_not_installed zsh || echo "Failed to install zsh, but continuing..."
install_if_not_installed unzip || echo "Failed to install unzip, but continuing..."

# Install zoxide
if ! command -v zoxide &> /dev/null; then
    echo "Installing zoxide..."
    ZOXIDE_INSTALL_SCRIPT="$CORRECT_HOME/zoxide_install.sh"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o "$ZOXIDE_INSTALL_SCRIPT" || { echo "Failed to download zoxide install script"; }
    if [ -f "$ZOXIDE_INSTALL_SCRIPT" ]; then
        chmod +x "$ZOXIDE_INSTALL_SCRIPT"
        chown "$CORRECT_USER:$CORRECT_USER" "$ZOXIDE_INSTALL_SCRIPT"

        # Modify the install script to use the correct installation directory
        sed -i 's|PREFIX=.*|PREFIX="$HOME/.local"|' "$ZOXIDE_INSTALL_SCRIPT"

        # Run the install script as the correct user
        sh -c "HOME=$CORRECT_HOME $ZOXIDE_INSTALL_SCRIPT" || { echo "Failed to install zoxide"; }

        # Clean up
        rm "$ZOXIDE_INSTALL_SCRIPT"

        echo "zoxide installation attempted."
    else
        echo "Zoxide install script not found. Skipping zoxide installation."
    fi
else
    echo "zoxide is already installed."
fi

# Install Oh My Posh
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    check_and_create_dir $CORRECT_HOME/.local/bin
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$CORRECT_HOME/.local/bin" || { echo "Failed to install Oh My Posh"; }
    chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local/bin" || { echo "Failed to change ownership of $CORRECT_HOME/.local/bin"; }
fi

# Create themes directory and download Zen theme for Oh My Posh
THEMES_DIR="$CORRECT_HOME/.config/oh-my-posh/themes"
check_and_create_dir "$THEMES_DIR"

ZEN_THEME_URL="https://raw.githubusercontent.com/dreamsofautonomy/zen-omp/main/zen.toml"
ZEN_THEME_PATH="$THEMES_DIR/zen.toml"
if [ ! -f "$ZEN_THEME_PATH" ]; then
    echo "Downloading Zen theme for Oh My Posh..."
    curl -o "$ZEN_THEME_PATH" "$ZEN_THEME_URL" || { echo "Failed to download Zen theme"; }
    chown "$CORRECT_USER:$CORRECT_USER" "$ZEN_THEME_PATH" || { echo "Failed to change ownership of $ZEN_THEME_PATH"; }
else
    echo "Zen theme already exists at $ZEN_THEME_PATH"
fi

# Install fd-find
case "$PKG_MANAGER" in
    apt-get)
        install_if_not_installed fd-find || echo "Failed to install fd-find, but continuing..."
        ;;
    dnf|yum)
        install_if_not_installed fd-find || echo "Failed to install fd-find, but continuing..."
        ;;
    *)
        echo "Please install fd-find manually."
        ;;
esac

# Install bat
install_if_not_installed bat || echo "Failed to install bat, but continuing..."

# Create symlinks if needed
if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
    sudo ln -s $(which fdfind) /usr/local/bin/fd || echo "Failed to create symlink for fd, but continuing..."
fi

if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
    sudo ln -s $(which batcat) /usr/local/bin/bat || echo "Failed to create symlink for bat, but continuing..."
fi

# Ensure correct ownership of user directories
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local" || echo "Failed to change ownership of $CORRECT_HOME/.local"
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.config" || echo "Failed to change ownership of $CORRECT_HOME/.config"

# Install fzf
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    if [ ! -d "$CORRECT_HOME/.fzf" ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$CORRECT_HOME/.fzf" || { echo "Failed to clone fzf repository"; }
    else
        echo "fzf directory already exists. Skipping clone."
    fi

    if [ -d "$CORRECT_HOME/.fzf" ]; then
        chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf" || { echo "Failed to change ownership of $CORRECT_HOME/.fzf"; }
        sudo -u "$CORRECT_USER" "$CORRECT_HOME/.fzf/install" --all || { echo "Failed to run fzf install script"; }
    else
        echo "fzf directory not found. Skipping installation."
    fi
else
    echo "fzf is already installed."
fi

# Install Zinit
ZINIT_HOME="${XDG_DATA_HOME:-${CORRECT_HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname "$ZINIT_HOME")" || { echo "Failed to create Zinit directory"; }
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" || { echo "Failed to clone Zinit repository"; }
    chown -R "$CORRECT_USER:$CORRECT_USER" "$(dirname "$ZINIT_HOME")" || { echo "Failed to change ownership of Zinit directory"; }
else
    echo "Zinit is already installed."
fi

# Clone fzf-git script
FZF_GIT_DIR="$CORRECT_HOME/.fzf-git"
if [ ! -d "$FZF_GIT_DIR" ]; then
    git clone https://github.com/junegunn/fzf-git.sh.git "$FZF_GIT_DIR" || { echo "Failed to clone fzf-git repository"; }
    chown -R "$CORRECT_USER:$CORRECT_USER" "$FZF_GIT_DIR" || { echo "Failed to change ownership of $FZF_GIT_DIR"; }
else
    echo "fzf-git is already installed."
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
        wget -c "https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_ARCH}.tar.gz" -O - | tar xz -C "$TEMP_DIR" || { echo "Failed to download or extract eza"; return 1; }
        chmod +x "$TEMP_DIR/eza" || { echo "Failed to make eza executable"; return 1; }
        chown root:root "$TEMP_DIR/eza" || { echo "Failed to change ownership of eza"; return 1; }
        mv "$TEMP_DIR/eza" /usr/local/bin/eza || { echo "Failed to move eza to /usr/local/bin"; return 1; }
        rm -rf "$TEMP_DIR"

        # Create symlink for exa compatibility
        if command -v exa &> /dev/null; then
            echo "Replacing exa with eza..."
            rm -f /usr/local/bin/exa
            ln -s /usr/local/bin/eza /usr/local/bin/exa || { echo "Failed to create symlink for exa"; }
        fi

        echo "eza installation attempted."
    else
        echo "eza is already installed."
    fi
}

# Call the function to install eza
install_eza || echo "Failed to install eza, but continuing..."

# Ensure .zshrc exists and has correct permissions
ZSHRC="$CORRECT_HOME/.zshrc"
touch "$ZSHRC" || { echo "Failed to create .zshrc file"; }
chown "$CORRECT_USER:$CORRECT_USER" "$ZSHRC" || { echo "Failed to change ownership of .zshrc"; }
chmod 644 "$ZSHRC" || { echo "Failed to set permissions for .zshrc"; }

# Function to safely append configurations to .zshrc
append_to_zshrc() {
    local content="$1"
    echo "$content" | sudo -u "$CORRECT_USER" tee -a "$ZSHRC" > /dev/null || { echo "Failed to append content to .zshrc"; }
}

# Add your zshrc content here
zshrc_content=$(cat << 'EOF'

# Path to the flag file
FLAG_FILE="$HOME/.zsh_first_run_complete"

# Check if the flag file exists
if [ ! -f "$FLAG_FILE" ]; then
    # Display the message
    echo "Welcome! This message will only appear once. Some dependencies might be installed during the first run."

    # Create the flag file to prevent this message from showing again
    touch "$FLAG_FILE"
fi

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
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local" || { echo "Failed to change ownership of $CORRECT_HOME/.local"; }
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.config" || { echo "Failed to change ownership of $CORRECT_HOME/.config"; }
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf" || { echo "Failed to change ownership of $CORRECT_HOME/.fzf"; }
sudo chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf-git" || { echo "Failed to change ownership of $CORRECT_HOME/.fzf-git"; }
sudo chown "$CORRECT_USER:$CORRECT_USER" "$ZSHRC" || { echo "Failed to change ownership of $ZSHRC"; }

append_to_zshrc "$zshrc_content"

echo "Zsh configuration completed for user $CORRECT_USER. Please restart your terminal or source your .zshrc file."

# Final check
if [ -f "$ZSHRC" ] && [ -d "$CORRECT_HOME/.local" ] && [ -d "$CORRECT_HOME/.config" ]; then
    echo "Setup completed successfully."
else
    echo "Setup completed with some issues. Please check the output above for any error messages."
fi
