#!/bin/sh

: "${RUN_COMMAND_TRIGGER_REGEX:=https?://}"
run_command() {
  desc=$1
  shift # this is to shift argument table to the left after removing $1.

  # Prepare temporary file
  tmpfile=$(mktemp "${TMPDIR:-/tmp}/cmd_output.XXXXXX") || exit 1
  fifofile="${tmpfile}.fifo"    # this fifo file required to display the result both in standard output and temp file.
  liveflag="${tmpfile}.live"
  newline=$(printf '\n')

  # Clean up instruction in case of exception
  trap 'rm -f "$tmpfile" "$fifofile" 2>/dev/null' EXIT HUP INT TERM

  printf "\r[\033[33m .... \033[0m] %s" "$desc"

  # Live output using FIFO and tee while also saving to a file (POSIX-compliant method)
  mkfifo "$fifofile" || { rm -f "$tmpfile"; return 1; }

  # Watcher: No print out before trigger detect URL from the stdout. Once a URL snippet detected, print out stdout
  awk -v re="$RUN_COMMAND_TRIGGER_REGEX" -v out="$tmpfile" -v flag="$liveflag" '
  BEGIN { live=0 }
  {
    print $0 >> out; fflush(out)
    if (!live && $0 ~ re) {
      live=1
      # 상태줄과 안 겹치도록 개행
      printf "\n"
      print $0; fflush(stdout)
      # 플래그 파일 생성 (touch 대체)
      print "" > flag; close(flag)
      next
    }
    if (live) {
      print $0; fflush(stdout)
    }
  }
  END { close(out) }
  ' <"$fifofile" &
  readerpid=$!

  # Run the actual command (redirect both standard output and error to FIFO)
  "$@" >"$fifofile" 2>&1
  cmdstatus=$?

  wait "$readerpid" 2>/dev/null
  rm -f "$fifofile"

  # Print out
  output=$(cat "$tmpfile")

  if [ "$cmdstatus" -eq 0 ]; then
    printf "\r[\033[32m  OK  \033[0m] %s\n" "$desc"
  else
    printf "\r[\033[31mFAILED\033[0m] %s\n" "$description"
  fi

  # Reprint policy:
  # - If no trigger occurred: show the buffered output once at the end
  # - If a trigger occurred: skip reprinting on success since it was already shown live.
  if [ ! -f "$liveflag" ]; then
    if [ -s "$tmpfile" ]; then
      # 길면 꼬리만 보고 싶을 때: tail -n "${RUN_COMMAND_TAIL:-200}" "$tmpfile" | sed 's/^/ |\t/'
      sed 's/^/ |\t/' "$tmpfile"
    fi
  elif [ "$cmdstatus" -ne 0 ]; then
    # 트리거 있었는데 실패했다면, 필요하면 꼬리만 추가 출력하도록 여기서 tail로 조절 가능
    : # (기본은 추가출력 안 함)
  fi

  return "$cmdstatus"
}

: "${RUN_COMMAND_TRIGGER_REGEX:=https?://}"
run_command_anim() {
  set +m
  desc=$1
  shift

  tmpfile=$(mktemp "${TMPDIR:-/tmp}/cmd_output.XXXXXX") || exit 1
  fifofile="${tmpfile}.fifo"
  liveflag="${tmpfile}.live"
  doneflag="${tmpfile}.done" # 작업 완료를 알리는 플래그

  trap 'rm -f "$tmpfile" "$fifofile" "$liveflag" "$doneflag" 2>/dev/null' EXIT HUP INT TERM

  mkfifo "$fifofile" || { rm -f "$tmpfile"; return 1; }

  # 1. Watcher (awk): 실시간 출력 및 로그 저장
  awk -v re="$RUN_COMMAND_TRIGGER_REGEX" -v out="$tmpfile" -v flag="$liveflag" '
  BEGIN { live=0 }
  {
    print $0 >> out; fflush(out)
    if (!live && $0 ~ re) {
      live=1
      printf "\n"
      print $0; fflush(stdout)
      print "" > flag; close(flag)
      next
    }
    if (live) { print $0; fflush(stdout) }
  }
  END { close(out) }
  ' <"$fifofile" &
  readerpid=$!

  # 2. Actual Command 실행 (백그라운드)
  (
    "$@" >"$fifofile" 2>&1
    echo $? > "${tmpfile}.status"
    touch "$doneflag" # 작업 완료 표시
  ) &
  cmdpid=$!

  # 3. KITT 스타일 애니메이션 (포그라운드)
  # 트리거가 발생(liveflag 생성)하기 전까지만 작동합니다.
  dots="[    ]"
  idx=0
  dir=1
  while [ ! -f "$doneflag" ]; do
    if [ -f "$liveflag" ]; then
        # 실시간 출력이 시작되면 애니메이션 중단 (줄 꼬임 방지)
        wait $cmdpid 2>/dev/null
        break
    fi

    # KITT 스타일 계산 (0->1->2->3->2->1->0)
    case $idx in
      0) dots="[ ·... ]" ;;
      1) dots="[ .·.. ]" ;;
      2) dots="[ ..·. ]" ;;
      3) dots="[ ...· ]" ;;
      4) dots="[ ..·. ]" ;;
      5) dots="[ .·.. ]" ;;
      6) dots="[ ·... ]" ;;
    esac

    printf "\r%s %s" "$dots" "$desc"

    idx=$((idx + dir))
    if [ $idx -eq 6 ] || [ $idx -eq 0 ]; then dir=$((dir * -1)); fi

    sleep 0.2
  done

  # 정리 및 결과 수집
  wait $readerpid 2>/dev/null
  cmdstatus=$(cat "${tmpfile}.status")
  rm -f "$fifofile" "$doneflag" "${tmpfile}.status"

  # 최종 상태 출력
  if [ "$cmdstatus" -eq 0 ]; then
    printf "\r[\033[32m  OK  \033[0m] %s\n" "$desc"
  else
    printf "\r[\033[31mFAILED\033[0m] %s\n" "$desc"
  fi

  # 후속 처리 (트리거 없었을 때만 로그 출력)
  if [ ! -f "$liveflag" ] && [ -s "$tmpfile" ]; then
    sed 's/^/ |\t/' "$tmpfile"
  fi

  set -m
  return "$cmdstatus"
}

unicode_to_utf8() {
    hex="$1"
    dec=$((16#$hex))

    if [ "$dec" -le 0x7F ]; then
        # 1-byte
        printf '\\x%02X' "$dec"
    elif [ "$dec" -le 0x7FF ]; then
        # 2-byte
        b1=$(( (dec >> 6) | 0xC0 ))
        b2=$(( (dec & 0x3F) | 0x80 ))
        printf '\\x%02X\\x%02X' "$b1" "$b2"
    elif [ "$dec" -le 0xFFFF ]; then
        # 3-byte
        b1=$(( (dec >> 12) | 0xE0 ))
        b2=$(( ((dec >> 6) & 0x3F) | 0x80 ))
        b3=$(( (dec & 0x3F) | 0x80 ))
        printf '\\x%02X\\x%02X\\x%02X' "$b1" "$b2" "$b3"
    elif [ "$dec" -le 0x10FFFF ]; then
        # 4-byte
        b1=$(( (dec >> 18) | 0xF0 ))
        b2=$(( ((dec >> 12) & 0x3F) | 0x80 ))
        b3=$(( ((dec >> 6) & 0x3F) | 0x80 ))
        b4=$(( (dec & 0x3F) | 0x80 ))
        printf '\\x%02X\\x%02X\\x%02X\\x%02X' "$b1" "$b2" "$b3" "$b4"
    else
        echo "Error: Invalid code point (U+$hex)" >&2
        return 1
    fi
}

parse_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/(/' | sed 's/$/)/'
}

function shorten_path_posix() {
  # This is POSIX compatible version of shorten_path
  path="${PWD%/}"
  [ -z "$path" ] && path="/"

  # Exception list handling
  case "$path" in
    "$HOME"*)
      alias_name="~"
      subpath="${path#$HOME}"
      ;;
    "/exp/${EXPERIMENT}/app/users/${USER}"*)
      alias_name="[appdir]"
      subpath="${path#"/exp/${EXPERIMENT}/app/users/${USER}"}"
      ;;
    "/exp/${EXPERIMENT}/data/users/${USER}"*)
      alias_name="[datadir]"
      subpath="${path#"/exp/${EXPERIMENT}/data/users/${USER}"}"
      ;;
    "/build/${USER}"*)
      alias_name="/build"
      subpath="${path#"/build/${USER}"}"
      ;;
    *)
      alias_name=""
      subpath="$path"
      ;;
  esac

  subpath="${subpath#/}"
  old_ifs="$IFS"
  IFS='/'

  set -f # prevent wild-card expansion
  set -- $subpath
  count=$#

  if [ -n "$alias_name" ]; then
    if [ $count -eq 0 ]; then
      printf "$alias_name"
    elif [ $count -eq 1 ]; then
      printf "$alias_name/$1"
    else
      shift $((count -1))
      printf "$alias_name/.../$1"
    fi
  else
    # ordinary absolute path case
    set -- $path
    count=$#
    if [ $count -le 2 ]; then
      printf "$path"
    else
      first="$1"
      shift $((count - 1))
      echo "/$first/.../$1"
    fi
  fi

  IFS="$old_ifs"
  set +f
}

function shorten_path() {
  (
  # Remove trailing slash if any
  path="${PWD%/}"
  home="$HOME"

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
  )
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
  # list of path exceptions
  # POSIX standard set_prompt
  RED=$(printf '\[\033[0;31m\]')
  GREEN=$(printf '\[\033[0;32m\]')
  BLUE=$(printf '\[\033[0;34m\]')
  YELLOW=$(printf '\[\033[0;33m\]')
  PURPLE=$(printf '\[\033[0;35m\]')
  CYAN=$(printf '\[\033[0;36m\]')
  RESET=$(printf '\[\033[0m\]')

  user_name="${USER:-$(whoami)}"
  host_name="${HOSTNAME:-$(uname -n)}"
  current_path=$(shorten_path_posix)
  git_branch=$(parse_git_branch)

  if [ -n "$APPTAINER_CONTAINER" ]; then
    prefix="${GREEN}[${RESET}${RED}Appt: ${RESET}"
  else
    prefix="${GREEN}[${RESET}"
  fi
  export PS1="${prefix}${CYAN}${user_name}${RESET}@${BLUE}${host_name}${RESET} ${current_path} ${YELLOW}${git_branch}${RESET}${GREEN}]${RESET} \$ "
}

upsls(){
  local package=$1
  if [ -z "$package" ]; then
    echo "Usage: upsls <package name>"
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
