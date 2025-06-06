#!/bin/bash

run_command() {
  local description="$1"
  shift # this is to shift argument table to the left after removing $1.
  echo -n "$description ... "
  "$@" # run the command with arguments
  if [ $? -eq 0 ]; then
    echo -e "[\033[32m OK \033[0m]"
    return 0
  else
    echo -e "[\033[31m FAILED \033[0m]"
    return 1
  fi
}

parse_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/(/' | sed 's/$/)/'
}

function shorten_path() {
  local path="$PWD"
  local home="$HOME"

  # Remove trailing slash if any
  path="${path%/}"

  # If path is inside home directory
  if [[ "$path" == "$home"* ]]; then
    # Remove $HOME prefix
    local subpath="${path#$home}"
    # Remove leading slash from subpath (if any)
    subpath="${subpath#/}"

    IFS='/' read -ra parts <<< "$subpath"
    local count=${#parts[@]}

    if (( count == 0 )); then
      echo "~"
    elif (( count == 1 )); then
      echo "~/${parts[0]}"
    else
      echo "~/.../${parts[count - 1]}"
    fi
  else
    IFS='/' read -ra parts <<< "$path"
    local count=${#parts[@]}

    if (( count <= 2 )); then
      echo "$path"
    else
      echo "/${parts[1]}/.../${parts[count - 1]}"
    fi
  fi
}

check_n_start_apptainer() {
  if [ -n "$APPTAINER_CONTAINER" ]; then
    echo "Running inside Apptainer"
    RED="\[\033[0;31m\]"
    GREEN="\[\033[0;32m\]"
    BLUE="\[\033[0;34m\]"
    YELLOW="\[\033[0;33m\]"
    PURPLE="\[\033[0;35m\]"
    CYAN="\[\033[0;36m\]"
    RESET="\[\033[0m\]"

    set_prompt
    return 0
  else
    echo "WARNING: Not inside Apptainer"
    return 1
  fi
}

set_prompt(){
  RED="\[\033[0;31m\]"
  GREEN="\[\033[0;32m\]"
  BLUE="\[\033[0;34m\]"
  YELLOW="\[\033[0;33m\]"
  PURPLE="\[\033[0;35m\]"
  CYAN="\[\033[0;36m\]"
  RESET="\[\033[0m\]"

  if [ -n "$APPTAINER_CONTAINER" ]; then
    export PS1="${GREEN}[${RESET}${RED}Appt: ${RESET}${CYAN}\u${RESET}@${BLUE}\h${RESET} \$(shorten_path) ${YELLOW}\$(parse_git_branch)${RESET}${GREEN}]${RESET} \$ "
  else
    export PS1="${GREEN}[${RESET}${CYAN}\u${RESET}@${BLUE}\h${RESET} \$(shorten_path) ${YELLOW}\$(parse_git_branch)${RESET}${GREEN}]${RESET} \$ "
  fi
}

ups_list_sort(){
  local package=$1
  if [ -z "$package" ]; then
    echo "Usage: ups_list_sort <package name>"
    return 1
  fi

  ups list -aK+ "$package" | \
    awk -F\" '{print $2, $4, $6, $8, $10}' | \
    sort -k2,2V | \
    awk '{printf "\"%s\" \"%s\" \"%s\" \"%s\" \"%s\"\n", $1, $2, $3, $4, $5}'
}

#alias real_cp='/bin/cp'
#cp() {
#  local use_ifdh=false
#
#  for arg in "$@"; do
#    if [[ "$arg" == /pnfs/* ]]; then
#      use_ifdh=true
#      break
#    fi
#  done
#
#  if $use_ifdh; then
#    echo "cp wrapper] Detected /pnfs path --> using ifdh cp"
#    ifdh cp "$@"
#  else
#    real_cp "$@"
#  fi
#}
