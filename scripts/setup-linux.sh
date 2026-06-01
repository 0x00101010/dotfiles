#!/bin/bash

# Update and upgrade system packages
sudo apt update
sudo apt upgrade -y

# Install chezmoi
sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

# configure CHEZMOI repo
git clone https://github.com/0x00101010/dotfiles.git ~/src/dotfiles
rm -rf ~/.local/share/chezmoi
mkdir -p ~/.local/share
ln -s ~/src/dotfiles ~/.local/share/chezmoi

chezmoi init
chezmoi apply -v