# editing config
alias ez="$EDITOR ~/.zshrc"     # alias for Edit Zshrc
alias ea="$EDITOR ~/.alias.zsh" # alias for Edit Alias
alias el="$EDITOR ~/.local.zsh" # alias for Edit Local
alias sz='source ~/.zshrc'      # alias for Source Zsh

# bookmarks
alias @tmp='cd ~/tmp'
alias @downloads='cd ~/Downloads'
alias @src='cd ~/src'
alias @repo='cd ~/src/monorepo'
alias @monorail='cd ~/src/coinbase'
alias @tfs='cd ~/src/tx_service'

# directory related
alias ls='ls -G'      # ls with color
alias l='ls -1A'      # list directory
alias ll='ls -lah'    # list directory with additional information
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# applications
alias tree='cb-tree -C'
alias d='docker'
alias v='nvim'
alias y='yarn'
alias m='make'

# create and delete files/folders
alias t='touch'   # create file
alias md='mkdir'  # make directory
alias rd='rm -rfi' # remove directory and file (interactive)

# misc.
alias q='exit'                                                                                # vim like quit command to close terminal pane
alias o='open'                                                                                # open file or chrome with full url
alias myip="ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'" # show my ip
alias pingg='ping www.google.com'                                                             # See network speed against google.com

# git
alias g='git'

# Commit Management
alias ga='git add'
alias gu='git unadd' # git config --global alias.unadd reset HEAD
alias grb='git rebase'
alias gcp='git cherry-pick'
alias gca='git commit -v --amend'
alias gc='git commit'
alias gempty="git commit --allow-empty -m 'empty'"
alias gps='git push origin $(git branch --show-current)'
alias gpu='git push upstream $(git branch --show-current)'
alias gpsf='git push francis $(git branch --show-current)'

# Branch Management
alias gb='git --no-pager branch' # make _git_push_auto_branch_local
alias gr='git remote -v'
alias gf='git fetch'
alias gfa='git fetch --all'

alias gco='git checkout'
alias gcob="git checkout -b"
alias gp='_git_push_auto_branch' # git push to origin on current branch if no argument specified. Otherwise, git push to specified remote. (from cb-zsh)
alias gprune="git remote prune origin | grep -o '\[pruned\] origin\/.*$' | sed -e 's/\[pruned\] origin\///' | xargs git branch -D"
alias gpum='git pull upstream main'
alias gpumaster='git pull upstream master'
alias gpud='git pull upstream develop'
alias gpom='git pull origin main'
alias gpomaster='git pull origin master'
alias gpod='git pull origin develop'


# Experimental
alias grhh="git reset --hard HEAD"
alias gsave='git add :/ && git commit -m "save point"'

# Git Status
alias gs='git status -sb' # short and concise
alias gst='git status'

# Git Log
alias gl="_git_commit_all"
alias gll='git log --stat'     # git log with file info
alias glll='git log --stat -p' # git log with file info + content

# Git Commits
alias glc='_git_commit_diff' # show commits diff against (upstream|origin)/master (from cb-zsh)

# Git Diff
alias gd='git diff HEAD'


# Git Worktree
alias gw='git worktree'
alias gwl='git worktree list'
alias gwa='git worktree add'
alias gwr='git worktree remove'
alias gwp='git worktree prune'

# Fuzzyhub
alias fco='fh checkout'
alias fcop='fh checkout-pr'
alias fsm='fh sync-master'
alias fpr='fh view-pr'
alias fm='fh view-master'
alias fl='fh view-local'

# Docker
alias dc='docker compose'
alias de='docker exec -it'
alias dl='docker logs'
alias dp='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpg='docker ps | grep'
alias dv='docker volume'
alias dvi='docker volume inspect'

alias cu='cursor'
alias co='code'
alias rr='RustRover'

# kubernetes
alias k='kubectl'
alias kx='kubectx'
alias kn='kubens'

alias tar='gtar'

alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo check'

# chezmoi
alias ci="chezmoi"
alias cia="chezmoi apply -v"
alias cid="cd ~/.local/share/chezmoi"
alias cz="chezmoi apply -v && source ~/.zshrc"

alias j="just"