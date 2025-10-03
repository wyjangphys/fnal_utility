#!/bin/bash

_dunegpvm_ssh_wrapper() {
  # config: path to file with selected index
  local sel_file="${HOME}/.local/etc/dunegpvm"
  local domain="${DUNEGPVM_DOMAIN:-.fnal.gov}"   # 기본 도메인, 필요하면 환경변수로 변경
  local pad_width="${DUNEGPVM_PAD:-2}"          # 호스트 인덱스 패딩 (02 -> 2)
  local fallback_action="${DUNEGPVM_FALLBACK:-error}" # error 또는 raw(원본 호스트로 접속)

  # copy args
  local -a args=("$@")
  local hostpos=-1
  # find first non-option argument (simple heuristic)
  for i in "${!args[@]}"; do
    a="${args[$i]}"
    # treat args starting with '-' as ssh option; also allow KEY=VAL style to be skipped
    if [[ "$a" != -* && "$a" != *=* ]]; then
      hostpos=$i
      break
    fi
  done

  # no positional host found -> call real ssh
  if [ "$hostpos" -lt 0 ]; then
    command ssh "${args[@]}"
    return $?
  fi

  local orig_target="${args[$hostpos]}"
  # split user and host (ssh syntax: [user@]host)
  local userpart=""
  local hostpart="$orig_target"
  if [[ "$orig_target" == *@* ]]; then
    userpart="${orig_target%@*}"
    hostpart="${orig_target#*@}"
  fi

  # If hostpart matches "dunegpvm" exactly (or starts with dunegpvm and no digits), we intercept.
  # We also accept plain "dunegpvm" (no domain).
  if [[ "$hostpart" =~ ^dunegpvm([[:digit:]]*)($|\.) ]]; then
    # read selected index
    if [ ! -r "$sel_file" ]; then
      echo "dunegpvm wrapper: selection file not found: $sel_file" >&2
      [ "$fallback_action" = "raw" ] && command ssh "${args[@]}" || return 1
    fi
    local sel
    sel="$(cat $sel_file)"
    #sel="$(<"$sel_file" 2>/dev/null || echo "-1")" || sel="-1"
    #sel="${sel//[[:space:]]/}"   # trim whitespace

    if [[ "$sel" == "-1" || -z "$sel" ]]; then
      echo "dunegpvm wrapper: no valid kerberos ticket or no selection (value='$sel')." >&2
      [ "$fallback_action" = "raw" ] && command ssh "${args[@]}" || return 2
    fi

    # format index with padding (02 -> 01,02,...)
    # POSIX printf supports %0Nd
    printf -v sel_padded "%0${pad_width}d" "$sel"

    # build new host: user@dunegpvmXX[.domain]
    local newhost=""
    if [ -n "$userpart" ]; then
      newhost="${userpart}@dunegpvm${sel_padded}${domain}"
    else
      newhost="dunegpvm${sel_padded}${domain}"
    fi

    # replace arg and call real ssh
    args[$hostpos]="$newhost"
    echo "ssh -> ${args[$hostpos]}" >&2    # optional: show mapping in stderr
    command ssh "${args[@]}"
    return $?
  else
    # host doesn't match dunegpvm pattern: call real ssh
    command ssh "${args[@]}"
    return $?
  fi
}

# override ssh in interactive shells
ssh() { _dunegpvm_ssh_wrapper "$@"; }

