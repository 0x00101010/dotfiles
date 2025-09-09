if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -U fish_autocd 1

# Add Homebrew to PATH
fish_add_path /opt/homebrew/bin

# init additional plugins
oh-my-posh init fish --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/emodipt-extend.omp.json | source
zoxide init fish | source

source ~/.config/fish/alias.fish


