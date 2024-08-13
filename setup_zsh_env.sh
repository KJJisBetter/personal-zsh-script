#!/bin/bash

set -e

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

# Install Oh My Posh if not already installed
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
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

# Install fzf if not already installed
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
fi

# Install Zinit if not already installed
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Clone fzf-git script
FZF_GIT_DIR="$HOME/.fzf-git"
if [ ! -d "$FZF_GIT_DIR" ]; then
    git clone https://github.com/junegunn/fzf-git.sh.git "$FZF_GIT_DIR"
fi

# Add configurations to .zshrc
cat << 'EOF' > ~/.zshrc
# Your existing .zshrc content here
# ...

# Ensure this is at the end of the file
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(zoxide init zsh)"
eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/themes/zen.toml)"
EOF

echo "Zsh configuration completed. Please restart your shell or run 'source ~/.zshrc'."
