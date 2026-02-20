#!/usr/bin/env bash
set -e

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Sane PATH when running as root (sudo often strips env, causing "command not found")
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"

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

# Determine the package manager and run update/upgrade (we are root, so no sudo needed)
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    echo "Updating and upgrading system packages..."
    apt-get update && apt-get upgrade -y
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    echo "Updating and upgrading system packages..."
    dnf upgrade -y
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    echo "Updating and upgrading system packages..."
    yum update -y
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

# Function to install a package if it's not already installed.
# Usage: install_if_not_installed <package> [command_name]
# If command_name is omitted, it defaults to package (for "command -v" check).
install_if_not_installed() {
    local package="$1"
    local command_name="${2:-$1}"
    if ! command -v "$command_name" &> /dev/null; then
        echo "Installing $package..."
        case "$PKG_MANAGER" in
            apt-get)
                apt-get install -y "$package" || { echo "Failed to install $package"; return 1; }
                ;;
            dnf|yum)
                $PKG_MANAGER install -y "$package" || { echo "Failed to install $package"; return 1; }
                ;;
            brew)
                brew install "$package" || { echo "Failed to install $package"; return 1; }
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
install_if_not_installed git || { echo "Failed to install git"; true; }

# Install zsh and unzip
install_if_not_installed zsh || { echo "Failed to install zsh, but continuing..."; true; }
install_if_not_installed unzip || { echo "Failed to install unzip, but continuing..."; true; }

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
    check_and_create_dir "$CORRECT_HOME/.local/bin"
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

# Install fd (package name differs: fd-find on apt/dnf, fd on brew; binary fdfind on Debian, fd on brew)
case "$PKG_MANAGER" in
    apt-get|dnf|yum)
        install_if_not_installed fd-find fdfind || { echo "Failed to install fd-find, but continuing..."; true; }
        ;;
    brew)
        install_if_not_installed fd || { echo "Failed to install fd, but continuing..."; true; }
        ;;
    *)
        echo "Please install fd (or fd-find) manually."
        ;;
esac

# Install bat (Debian/Ubuntu: binary is batcat; brew: binary is bat)
case "$PKG_MANAGER" in
    apt-get|dnf|yum)
        install_if_not_installed bat batcat || { echo "Failed to install bat, but continuing..."; true; }
        ;;
    brew)
        install_if_not_installed bat bat || { echo "Failed to install bat, but continuing..."; true; }
        ;;
    *)
        install_if_not_installed bat bat || { echo "Please install bat manually."; true; }
        ;;
esac

# Create symlinks if needed
if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
    ln -s "$(which fdfind)" /usr/local/bin/fd || { echo "Failed to create symlink for fd, but continuing..."; true; }
fi

if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
    ln -s "$(which batcat)" /usr/local/bin/bat || { echo "Failed to create symlink for bat, but continuing..."; true; }
fi

# Ensure correct ownership of user directories
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local" || true
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.config" || true

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
        sudo -u "$CORRECT_USER" "$CORRECT_HOME/.fzf/install" --all || { echo "Failed to run fzf install script"; true; }
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
            aarch64|arm64)
                EZA_ARCH="aarch64-unknown-linux-gnu"
                ;;
            armv7l|arm)
                EZA_ARCH="arm-unknown-linux-gnueabihf"
                ;;
            *)
                echo "Unsupported architecture: $ARCH"
                return 1
                ;;
        esac

        # Download and install eza (tarball may have binary at root or in a subdir).
        # Checksums (sha256) are published on the GitHub release page for verification.
        TEMP_DIR=$(mktemp -d)
        wget -c "https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_ARCH}.tar.gz" -O - | tar xz -C "$TEMP_DIR" || { echo "Failed to download or extract eza"; rm -rf "$TEMP_DIR"; return 1; }
        EZA_BIN=$(find "$TEMP_DIR" -name eza -type f 2>/dev/null | head -n1)
        if [ -z "$EZA_BIN" ] || [ ! -f "$EZA_BIN" ]; then
            echo "eza binary not found in tarball"
            rm -rf "$TEMP_DIR"
            return 1
        fi
        chmod +x "$EZA_BIN" || { rm -rf "$TEMP_DIR"; return 1; }
        chown root:root "$EZA_BIN" || { rm -rf "$TEMP_DIR"; return 1; }
        mv "$EZA_BIN" /usr/local/bin/eza || { rm -rf "$TEMP_DIR"; return 1; }
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

# Call the function to install eza (optional)
install_eza || { echo "Failed to install eza, but continuing..."; true; }

# Ensure .zshrc exists and has correct permissions
ZSHRC="$CORRECT_HOME/.zshrc"
touch "$ZSHRC" || { echo "Failed to create .zshrc file"; }
chown "$CORRECT_USER:$CORRECT_USER" "$ZSHRC" || { echo "Failed to change ownership of .zshrc"; }
chmod 644 "$ZSHRC" || { echo "Failed to set permissions for .zshrc"; }

# Marker for our injected block (idempotent: re-run replaces block instead of duplicating)
ZSHRC_MARKER_START="# --- personal-zsh-script block ---"

# Function to write .zshrc block idempotently: replace existing block or append
write_zshrc_block() {
    local content="$1"
    if grep -q "^${ZSHRC_MARKER_START}$" "$ZSHRC" 2>/dev/null; then
        # Replace from marker to end of file with new content
        sed -i "/^${ZSHRC_MARKER_START}$/,\$d" "$ZSHRC" || { echo "Failed to remove old block from .zshrc"; return 1; }
        echo "$ZSHRC_MARKER_START" | sudo -u "$CORRECT_USER" tee -a "$ZSHRC" > /dev/null || return 1
        echo "$content" | sudo -u "$CORRECT_USER" tee -a "$ZSHRC" > /dev/null || { echo "Failed to write content to .zshrc"; return 1; }
    else
        echo "$ZSHRC_MARKER_START" | sudo -u "$CORRECT_USER" tee -a "$ZSHRC" > /dev/null || return 1
        echo "$content" | sudo -u "$CORRECT_USER" tee -a "$ZSHRC" > /dev/null || { echo "Failed to append content to .zshrc"; return 1; }
    fi
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
# Arch Linux helpers (only on Arch)
[[ -f /etc/arch-release ]] && zinit snippet OMZP::archlinux
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
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"

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
source "$HOME/.fzf-git/fzf-git.sh"

# Shell integration
eval "$(zoxide init zsh)"

# oh my posh customization for zsh
eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/themes/zen.toml")"
EOF
)

# Ensure correct ownership of user directories
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.local" || true
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.config" || true
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf" 2>/dev/null || true
chown -R "$CORRECT_USER:$CORRECT_USER" "$CORRECT_HOME/.fzf-git" 2>/dev/null || true
chown "$CORRECT_USER:$CORRECT_USER" "$ZSHRC" || true

write_zshrc_block "$zshrc_content"

# Final check and instructions
if [ -f "$ZSHRC" ] && [ -d "$CORRECT_HOME/.local" ] && [ -d "$CORRECT_HOME/.config" ]; then
    echo "Setup completed successfully."
    echo ""
    echo "Zsh configuration is ready for user $CORRECT_USER."
    echo ""
    echo "To use your new Zsh setup, run Zsh (do NOT run 'source ~/.zshrc' from Bash):"
    echo "  • Run:     zsh"
    echo "  • Or set Zsh as default, then log out and back in:"
    echo "    chsh -s \$(which zsh)"
    echo ""
else
    echo "Setup completed with some issues. Please check the output above for any error messages."
fi
