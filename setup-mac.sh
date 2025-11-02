#!/bin/bash

# Install package manager homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# # install pre-requisites
brew update
brew install chezmoi

# configure CHEZMOI repo
git clone https://github.com/0x00101010/dotfiles.git
rm -rf ~/.local/share/chezmoi
ln -s ~/src/dotfiles ~/.local/share/chezmoi
chezmoi init
chezmoi apply -v