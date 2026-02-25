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
# Usage: gwa <branch-name> [path]  (path defaults to ../<branch-name>)
gwa() {
    local branch=$1
    local dest=${2:-"../$branch"}

    if [[ -z "$branch" ]]; then
        echo "Usage: wadd <branch-name> [path]"
        return 1
    fi

    git worktree add "$dest" -b "$branch" && cd "$dest"
}

# Remove a worktree and cd to ../main
# Usage: gwrm [path]  (defaults to current directory)
gwrm() {
    local dest=${1:-$(pwd)}
    dest=$(cd "$dest" && pwd)
    local main=$(dirname "$dest")/main

    git worktree remove "$dest" && cd "$main"
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
