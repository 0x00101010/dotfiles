#!/usr/bin/env bash
# Claude Code statusline script
# Receives JSON input on stdin with workspace, model, context, etc.

input=$(cat)

# Basic info
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
time_str=$(date +%H:%M)
user=$(whoami)
host=$(hostname -s)

# Git info
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.fileMode=false rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    git_status=$(git -C "$cwd" -c core.fileMode=false status --porcelain 2>/dev/null)
    staged_count=$(echo "$git_status" | grep -c '^[MADRC]' 2>/dev/null || echo "0")
    working_count=$(echo "$git_status" | grep -c '^.[MD]' 2>/dev/null || echo "0")
    stash_count=$(git -C "$cwd" -c core.fileMode=false stash list 2>/dev/null | wc -l | tr -d ' ')

    git_info=$(printf "\033[38;5;221m")
    if [[ ${#branch} -gt 25 ]]; then
      git_info+="${branch:0:25}..."
    else
      git_info+="$branch"
    fi
    if [[ "$working_count" -gt 0 ]]; then
      git_info+=" ✎ $working_count"
    fi
    if [[ "$staged_count" -gt 0 ]]; then
      if [[ "$working_count" -gt 0 ]]; then git_info+=" |"; fi
      git_info+=" ✦ $staged_count"
    fi
    if [[ "$stash_count" -gt 0 ]]; then
      git_info+=" ≡ $stash_count"
    fi
    git_info+=$(printf "\033[0m")
    git_info=" $git_info "
  fi
fi

# Context window remaining
remaining=$(echo "$input" | jq -r '.context.remaining_percent // .context_window.remaining_percentage // .remaining_percentage // empty')
context_info=""
if [[ -n "$remaining" ]]; then
  remaining_int=$(printf "%.0f" "$remaining")
  if [[ "$remaining_int" -lt 20 ]]; then
    color="\033[38;5;196m"
  elif [[ "$remaining_int" -lt 50 ]]; then
    color="\033[38;5;214m"
  else
    color="\033[38;5;156m"
  fi
  context_info=$(printf " %b[%s%% left]\033[0m" "$color" "$remaining_int")
fi

# Model and output style
model=$(echo "$input" | jq -r '.model.display_name // empty')
output_style=$(echo "$input" | jq -r '.output_style.name // .output_style // empty')

# Line 1: time, git, user@host, cwd, context
printf "\033[38;5;180m[%s]\033[0m" "$time_str"
printf "%s" "$git_info"
printf "\033[38;5;156m %s@%s \033[0m" "$user" "$host"
printf "\033[38;5;75m%s\033[0m" "$cwd"
printf "\n"

# Line 2:
printf "\033[38;5;141m%s\033[0m" "$model"
printf "%s " "$context_info"
printf "\033[38;5;180m%s\033[0m" "output-style: $output_style"
printf "\n"