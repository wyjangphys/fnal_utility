# put this into your ~/.bashrc or ~/.zshrc and then source the file
_icarusgpvm_ssh_wrapper() {
  # config
  local sel_file="${HOME}/.local/etc/icarusgpvm"
  local domain="${ICARUSGPVM_DOMAIN:-.fnal.gov}"
  local pad_width="${ICARUSGPVM_PAD:-2}"
  local fallback_action="${ICARUSGPVM_FALLBACK:-error}"

  # detect shell and handle arrays appropriately
  if [ -n "${BASH_VERSION:-}" ]; then
    # --- BASH path (0-based arrays) ---
    local -a args=("$@")
    local hostpos=-1
    local i
    for i in "${!args[@]}"; do
      a="${args[$i]}"
      if [ "${a#-}" = "$a" ] && [ "${a#*=}" = "$a" ]; then
        hostpos=$i
        break
      fi
    done

    if [ "$hostpos" -lt 0 ]; then
      command ssh "${args[@]}"
      return $?
    fi

    local orig_target="${args[$hostpos]}"
    local userpart=""
    local hostpart="$orig_target"
    if [[ "$orig_target" == *@* ]]; then
      userpart="${orig_target%@*}"
      hostpart="${orig_target#*@}"
    fi

    if [[ "$hostpart" =~ ^icarusgpvm([[:digit:]]*)($|\.) ]]; then
      if [ ! -r "$sel_file" ]; then
        printf 'icarusgpvm wrapper: selection file not found: %s\n' "$sel_file" >&2
        [ "$fallback_action" = "raw" ] && command ssh "${args[@]}" || return 1
      fi

      local sel
      sel="$(tr -d '[:space:]' < "$sel_file" 2>/dev/null || true)"

      if [ -z "$sel" ] || [ "$sel" = "-1" ]; then
        printf 'icarusgpvm wrapper: no valid selection (value=%q)\n' "$sel" >&2
        [ "$fallback_action" = "raw" ] && command ssh "${args[@]}" || return 2
      fi

      if ! printf '%s\n' "$sel" | grep -Eq '^[0-9]+$'; then
        printf 'icarusgpvm wrapper: selection is not numeric: %s\n' "$sel" >&2
        return 3
      fi

      local sel_padded
      sel_padded=$(printf "%0${pad_width}d" "$sel")

      local newhost
      if [ -n "$userpart" ]; then
        newhost="${userpart}@icarusgpvm${sel_padded}${domain}"
      else
        newhost="icarusgpvm${sel_padded}${domain}"
      fi

      args[$hostpos]="$newhost"
      printf 'ssh -> %s\n' "${args[$hostpos]}" >&2
      command ssh "${args[@]}"
      return $?
    else
      command ssh "${args[@]}"
      return $?
    fi

  elif [ -n "${ZSH_VERSION:-}" ]; then
    # --- ZSH path (1-based arrays) ---
    typeset -a args
    args=("$@")   # zsh arrays are 1-based
    local hostpos=0
    local idx=1
    local a
    for a in "${args[@]}"; do
      # treat args starting with '-' as option; KEY=VAL skip
      if [ "${a#-}" = "$a" ] && [ "${a#*=}" = "$a" ]; then
        hostpos=$idx
        break
      fi
      idx=$((idx+1))
    done

    if [ "$hostpos" -eq 0 ]; then
      command ssh "${args[@]}"
      return $?
    fi

    # in zsh arrays are 1-based, so args[hostpos] is correct
    local orig_target="${args[$hostpos]}"
    local userpart=""
    local hostpart="$orig_target"
    if [[ "$orig_target" == *@* ]]; then
      userpart="${orig_target%@*}"
      hostpart="${orig_target#*@}"
    fi

    if [[ "$hostpart" =~ ^icarusgpvm([[:digit:]]*)($|\.) ]]; then
      if [ ! -r "$sel_file" ]; then
        printf 'icarusgpvm wrapper: selection file not found: %s\n' "$sel_file" >&2
        [ "$fallback_action" = "raw" ] && command ssh "${args[@]}" || return 1
      fi

      local sel
      sel="$(tr -d '[:space:]' < "$sel_file" 2>/dev/null || true)"

      if [ -z "$sel" ] || [ "$sel" = "-1" ]; then
        printf 'icarusgpvm wrapper: no valid selection (value=%q)\n' "$sel" >&2
        [ "$fallback_action" = "raw" ] && command ssh "${args[@]}" || return 2
      fi

      if ! printf '%s\n' "$sel" | grep -Eq '^[0-9]+$'; then
        printf 'icarusgpvm wrapper: selection is not numeric: %s\n' "$sel" >&2
        return 3
      fi

      local sel_padded
      sel_padded=$(printf "%0${pad_width}d" "$sel")

      local newhost
      if [ -n "$userpart" ]; then
        newhost="${userpart}@icarusgpvm${sel_padded}${domain}"
      else
        newhost="icarusgpvm${sel_padded}${domain}"
      fi

      args[$hostpos]="$newhost"
      printf 'ssh -> %s\n' "${args[$hostpos]}" >&2
      command ssh "${args[@]}"
      return $?
    else
      command ssh "${args[@]}"
      return $?
    fi

  else
    # unknown shell: fall back to calling ssh with original args
    command ssh "$@"
    return $?
  fi
}

# override ssh in interactive shells only
case $- in
  *i*) ssh() { _icarusgpvm_ssh_wrapper "$@"; } ;;
  *) : ;;
esac

