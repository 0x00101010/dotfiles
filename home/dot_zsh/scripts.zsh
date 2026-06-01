# git push to origin on current branch if no argument specified. Otherwise, git push to specified remote.
_git_push_auto_branch() {
    local remote
    local rest
    # remote is a git push option
    if [[ $1 = -* ]]; then
        remote="origin"
        rest=("$@")
    # no argument supplied
    elif [[ -z $1 ]]; then
        remote="origin"
        rest=("$@")
    # remote name provided
    else
        remote=$1
        shift
        rest=("$@")
    fi
    git push -u $remote $(git symbolic-ref --short -q HEAD) "${rest[@]}"
}

# show commit diff against upstream/master. Use origin if upstream doesn't exist
_git_commit_diff() {
    # check if upstream remote repository exists
    local upstream=$(git remote | grep upstream)
    if [[ -z "$upstream" ]]; then
        # use origin instead of upstream
        upstream=origin
    fi

    git log --color --graph --pretty=format:"%Cred%h%Creset %C(blue)<%an>%Creset %s -%C(bold yellow)%d%Creset %Cgreen(%cr)" --abbrev-commit $upstream/master..
}

# show all commits
_git_commit_all() {
    git log --color --graph --pretty=format:"%Cred%h%Creset %C(blue)<%an>%Creset %s -%C(bold yellow)%d%Creset %Cgreen(%cr)" --abbrev-commit
}

_git_prompt_git() {
    GIT_OPTIONAL_LOCKS=0 command git "$@"
}

# outputs the name of the current branch
_git_current_branch() {
    local ref
    ref=$(_git_prompt_git symbolic-ref --quiet HEAD 2>/dev/null)
    local ret=$?
    if [[ $ret != 0 ]]; then
        [[ $ret == 128 ]] && return # no git repo.
        ref=$(_git_prompt_git rev-parse --short HEAD 2>/dev/null) || return
    fi
    echo ${ref#refs/heads/}
}
