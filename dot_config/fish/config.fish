if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -U fish_autocd 1

# Add Homebrew to PATH
fish_add_path /opt/homebrew/bin
fish_add_path (npm get prefix)/bin

# direnv enable, before oh-my-posh
direnv hook fish | source

# init additional plugins
oh-my-posh init fish --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/emodipt-extend.omp.json | source
zoxide init fish | source
aws_completer fish | source

source ~/.config/fish/alias.fish

# Enable mise automatically if installed
if command -v mise >/dev/null
    # Run mise activation for fish
    mise activate fish | source
end

# Carapace setup
set -Ux CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense' # optional
carapace _carapace | source

if test -f ~/.config/fish/local.fish
    source ~/.config/fish/local.fish
end