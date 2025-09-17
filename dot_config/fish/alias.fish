# editing config
alias sz="source ~/.config/fish/config.fish"      # alias for Source Zsh

# bookmarks
alias @tmp="cd ~/tmp"
alias @downloads="cd ~/Downloads"
alias @src="cd ~/src"
alias @repo="cd ~/src/monorepo"
alias @monorail="cd ~/src/coinbase"
alias @tfs="cd ~/src/tx_service"

# directory related
alias ls="ls -G"      # ls with color
alias l="ls -1A"      # list directory
alias ll="ls -lah"    # list directory with additional information
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# applications
alias tree="cb-tree -C"
alias d="docker"
alias dc="docker-compose"
alias v="nvim"
alias y="yarn"
alias m="make"

# create and delete files/folders
alias t="touch"   # create file
alias md="mkdir"  # make directory
alias rd="rm -rf" # remove directory and file

# misc.
alias q="exit"                                                                                # vim like quit command to close terminal pane
alias o="open"                                                                                # open file or chrome with full url
alias pingg="ping www.google.com"                                                             # See network speed against google.com

# git
alias g="git"

# Commit Management
alias ga="git add"
alias gu="git unadd" # git config --global alias.unadd reset HEAD
alias grb="git rebase"
alias gcp="git cherry-pick"
alias gca="git commit -v --amend"
alias gc="git commit"
alias gempty="git commit --allow-empty -m "empty""

function gps
    git push origin $(git branch --show-current)
end

function gpu
    git push upstream $(git branch --show-current)
end

# Branch Management
alias gb="git --no-pager branch" # make _git_push_auto_branch_local
alias gr="git remote -v"
alias gf="git fetch"
alias gfa="git fetch --all"

alias gco="git checkout"
alias gcob="git checkout -b"
alias gp="_git_push_auto_branch" # git push to origin on current branch if no argument specified. Otherwise, git push to specified remote. (from cb-zsh)
alias gpum="git pull upstream master"
alias gpumain="git pull upstream main"
alias gpud="git pull upstream develop"
alias gpom="git pull origin master"
alias gpomain="git pull origin main"
alias gpod="git pull origin develop"
alias grhh="git reset --hard HEAD"

# Experimental
alias gpop="git reset --soft head^ && git unadd :/"
alias gsave='git add :/ && git commit -m "save point"'

# Git Status
alias gs="git status -sb" # short and concise
alias gst="git status"

# Git Log
alias gl='git log --color --graph --pretty=format:"%Cred%h%Creset %C(blue)<%an>%Creset %s -%C(bold yellow)%d%Creset %Cgreen(%cr)" --abbrev-commit'
alias gll="git log --stat"     # git log with file info
alias glll="git log --stat -p" # git log with file info + content

# Git Commits
alias glc="_git_commit_diff" # show commits diff against (upstream|origin)/master (from cb-zsh)

# Git Diff
alias gd="git diff HEAD"

# Git Reset
alias grhh="git reset --hard HEAD"

# Git Worktree
alias gw="git worktree"
alias gwl="git worktree list"
alias gwa="git worktree add"
alias gwr="git worktree remove"
alias gwp="git worktree prune"

# Fuzzyhub
alias fco="fh checkout"
alias fcop="fh checkout-pr"
alias fsm="fh sync-master"
alias fpr="fh view-pr"
alias fm="fh view-master"
alias fl="fh view-local"

# Docker
alias dc="docker compose"
alias de="docker exec -it"
alias dl="docker logs"
alias dp='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpg="docker ps | grep"

alias cu="cursor"
alias co="code"

# kubernetes
alias k="kubectl"
alias kx="kubectx"
alias kn="kubens"

alias tar="gtar"

alias cr="cargo run"
alias ct="cargo test"
alias cc="cargo check"

# chezmoi
alias ci="chezmoi"
alias cia="chezmoi apply -v"
alias cid="cd ~/.local/share/chezmoi"
alias cs="chezmoi apply -v && source ~/.config/fish/config.fish"
