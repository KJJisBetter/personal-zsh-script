# Personal ZSH Script

This repository contains a shell script that sets up a customized Zsh environment with various tools and configurations to enhance your command-line experience.

## Quick Start

**Recommended (download, review, then run):**

```sh
curl -sSL -o setup_zsh_env.sh https://raw.githubusercontent.com/KJJIsBetter/personal-zsh-script/master/setup_zsh_env.sh
chmod +x setup_zsh_env.sh   # required when downloading (e.g. curl or GitHub zip); clones usually get the bit already
# Review the script before running with sudo
sudo ./setup_zsh_env.sh
```

If you clone the repo with Git, the script is usually executable already; on Ubuntu, if you get "Permission denied", run `chmod +x setup_zsh_env.sh` once.

Piping a remote script directly into `sudo sh` is unsafe (no local copy to review; a partial download could run incomplete code). Prefer the above so you can inspect the script first.

After the script finishes, **use Zsh** so your new config is loaded. Do one of the following:

- **Option A:** Run `zsh` in the same terminal (Zsh will automatically load `.zshrc`).
- **Option B:** Open a new terminal; if Zsh is already your default shell, it will load automatically.
- **Option C:** Make Zsh your default shell, then log out and back in:
  ```sh
  chsh -s $(which zsh)
  ```

**Do not** run `source .zshrc` from Bash—`.zshrc` is for Zsh only and will fail in Bash.

## What This Script Does

At the start, the script asks: **"Will this environment primarily be used in Warp terminal? [y/N]"** Your choice affects what gets installed and how `.zshrc` is configured.

- **If you answer No (or just press Enter):** Full setup with **smarter autosuggestions** (history + completion strategy) and all tools. Best for standard terminals (e.g. GNOME Terminal, Konsole, iTerm2).
- **If you answer Yes (Warp):** The script tells you that the experience in Warp won’t match a standard terminal (Warp has its own UI and features). It still installs core tools and Zsh config (Oh My Posh, plugins), but **does not** add the smarter-autosuggestions config. It then installs **Warp themes** (with an optional prompt to clone all official themes or skip). You pick the theme inside Warp under **Settings > Appearance > Theme**.

The script automates the rest as follows:

1. **System Update:** Updates and upgrades system packages using the appropriate package manager (apt, dnf, yum, or brew).

2. **Tool Installation:** Installs and configures the following tools:
   - Zsh
   - Git
   - Oh My Posh (for prompt customization)
   - Zoxide (for smart directory navigation)
   - fzf (for fuzzy finding)
   - fd-find (for faster file searching)
   - bat (for syntax highlighting in cat command)
   - eza (a modern replacement for ls)

3. **Zsh Configuration:** Sets up a .zshrc file with:
   - Zinit plugin manager
   - Various Zsh plugins for syntax highlighting, autosuggestions, and completions
   - When **not** using Warp: smarter autosuggestions (`ZSH_AUTOSUGGEST_STRATEGY=(history completion)`)
   - Custom keybindings and history settings
   - Aliases for common commands
   - FZF integration for enhanced searching

4. **Theme Setup:** Installs the Zen theme for Oh My Posh (from [dreamsofautonomy/zen-omp](https://github.com/dreamsofautonomy/zen-omp)).

5. **Warp-only (if you chose Warp):** Creates the Warp themes directory and, if you opt in, clones the [official Warp themes](https://github.com/warpdotdev/themes) so you can select one in Warp’s theme picker.

The script uses [Zinit](https://github.com/zdharma-continuum/zinit) (zdharma-continuum/zinit) as the Zsh plugin manager and [Oh My Posh](https://ohmyposh.dev/) for the prompt. Re-running the script is idempotent: it replaces its own block in `.zshrc` instead of appending a duplicate. On Arch Linux, the Arch-specific Oh My Zsh snippet is loaded; on other distros it is skipped.

## Warp Terminal

If you indicated that you mainly use **Warp**:

- **Themes** are installed (when you choose to clone them) at:
  - **Linux:** `~/.local/share/warp-terminal/themes/` (or `$XDG_DATA_HOME/warp-terminal/themes/` if set)
  - **macOS:** `~/.warp/themes/`
- Warp has no CLI to switch themes; select your theme in Warp under **Settings > Appearance > Theme**.
- Your `.zshrc` still loads Oh My Posh and plugins; if you see a duplicate prompt in Warp, enable the setting that uses the **shell’s prompt** (e.g. “Use shell prompt” or “Custom prompt”) in Warp’s appearance options.

## Why These Choices?

- **Zsh:** Offers more features and customization options compared to bash.
- **Oh My Posh:** Provides a customizable and informative prompt.
- **Zoxide:** Enables faster navigation between directories.
- **fzf:** Enhances search capabilities in the command line.
- **fd-find & bat:** Modern alternatives to find and cat with improved functionality.
- **eza:** A more feature-rich and colorful alternative to the ls command.

The fzf installer is run with `--all`, so keybindings and completion are set up for all supported shells (Bash, Zsh, etc.). If you prefer Zsh only, you can re-run `~/.fzf/install` with the appropriate flags after setup.

## Customization

The script sets up a basic configuration. You can further customize your Zsh environment by modifying the `.zshrc` file in your home directory.

## Troubleshooting

If you encounter any issues during installation, check the console output for error messages. Most common issues can be resolved by ensuring you have the necessary permissions and that your system is up to date.

## Contributing

Feel free to fork this repository and submit pull requests with improvements or additional features.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
