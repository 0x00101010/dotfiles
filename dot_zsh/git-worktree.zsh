# Clone repo as bare + worktree setup
gwc() {
    local repo_url=$1
    local folder_name=${2:-$(basename "$repo_url" .git)}

    if [[ -z "$repo_url" ]]; then
        echo "Usage: wclone <repo-url> [folder-name]"
        return 1
    fi

    local default_branch=$(git ls-remote --symref "$repo_url" HEAD | awk '/^ref:/ {sub(/refs\/heads\//, "", $2); print $2}')
    : ${default_branch:=main}

    mkdir -p "$folder_name" && cd "$folder_name" || return 1

    git clone --bare "$repo_url" .bare
    echo "gitdir: ./.bare" > .git

    (cd .bare && git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" && git fetch origin)

    git worktree add "$default_branch" "$default_branch"

    echo ""
    echo "✅ Done! Project ready at $(pwd)"
    echo "📂 Default worktree: $(pwd)/$default_branch"
    echo ""
    echo "Quick commands:"
    echo "  cd $folder_name/$default_branch"
    echo "  git worktree add <name> -b <new-branch> $default_branch"
}

# Add a worktree and cd into it
# Usage: gwa <branch-name> [path]  (path defaults to <repo-root>/<branch-name>)
gwa() {
    local branch=$1

    if [[ -z "$branch" ]]; then
        echo "Usage: gwa <branch-name> [path]"
        return 1
    fi

    local dest=$2
    if [[ -z "$dest" ]]; then
        local git_common_dir
        git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || {
            echo "Not in a git repository"
            return 1
        }
        dest="$(cd "$git_common_dir/.." && pwd)/$branch"
    fi

    git worktree add "$dest" -B "$branch" && cd "$dest"
}

# Remove a worktree and cd to main
# Usage: gwrm [.|worktree-name]  (defaults to current worktree)
gwrm() {
    local input=${1:-.}

    # Find repo root (parent of .bare)
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || {
        echo "Not in a git repository"
        return 1
    }
    local repo_root
    repo_root=$(cd "$git_common_dir/.." && pwd)

    # Resolve the worktree to remove
    local dest
    if [[ "$input" == "." ]]; then
        dest=$(git rev-parse --show-toplevel 2>/dev/null)
    else
        dest="$repo_root/$input"
    fi

    local main="$repo_root/main"

    if [[ "$dest" == "$main" ]]; then
        echo "Cannot remove main worktree"
        return 1
    fi

    # cd out first if we're inside the worktree being removed
    if [[ "$(pwd)" == "$dest" || "$(pwd)" == "$dest/"* ]]; then
        cd "$main" || return 1
    fi

    git worktree remove "$dest" && { [[ -d "$dest" ]] && rm -rf "$dest"; cd "$main"; }
}

# cd to the main/master worktree
gwm() {
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || {
        echo "Not in a git repository"
        return 1
    }
    local repo_root
    repo_root=$(cd "$git_common_dir/.." && pwd)

    for branch in main master; do
        if [[ -d "$repo_root/$branch" ]]; then
            cd "$repo_root/$branch"
            return
        fi
    done

    echo "No main or master worktree found in $repo_root"
    return 1
}

# Add remote with proper fetch config for worktree repos
gwr() {
    local remote_name=$1
    local remote_url=$2

    if [[ -z "$remote_name" ]] || [[ -z "$remote_url" ]]; then
        echo "Usage: wremote <name> <url>"
        return 1
    fi

    git remote add "$remote_name" "$remote_url"
    git config remote."$remote_name".fetch "+refs/heads/*:refs/remotes/$remote_name/*"
    git fetch "$remote_name"

    echo "✅ Remote '$remote_name' added and fetched"
}
