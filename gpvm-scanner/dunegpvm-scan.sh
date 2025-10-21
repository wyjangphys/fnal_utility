#!/usr/bin/env bash
#set -euo pipefail

# Detect OS
case "$(uname -s)" in
  Darwin)
    OS_TYPE="macos"
    ;;
  Linux)
    OS_TYPE="linux"
    ;;
  *)
    OS_TYPE="unknown"
    ;;
esac

if [ "$OS_TYPE" = "unknown" ]; then
  echo "Unsupported OS: $(uname -s)" >&2
  exit 1
fi

# macOS-friendly PATH (Homebrew / system)
if [ "$OS_TYPE" = "macos" ]; then
  # Homebrew가 설치되어 있다면 그 경로를 우선 사용
  if command -v brew >/dev/null 2>&1; then
    export PATH="$(brew --prefix)/bin:$PATH"
  fi
  export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
fi

# ---------------------------------- Configuration ----------------------------
USERNAME=${USERNAME:-${USER:-$(whoami)}}
REALM="${REALM:-FNAL.GOV}"
PRINCIPAL="${PRINCIPAL:-${USERNAME}@${REALM}}"

HOST_PREFIX="${HOST_PREFIX:-dunegpvm}"
DOMAIN="${DOMAIN:-fnal.gov}"
DUNEGPVM_START="${DUNEGPVM_START:-1}"
DUNEGPVM_END="${DUNEGPVM_END:-16}"
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-6}"
SSH_OPTS="-o ConnectTimeout=${SSH_CONNECT_TIMEOUT} -o BatchMode=yes -o StrictHostkeyChecking=no"
SSH_OPTS_ARRAY=(
  -o GSSAPIAuthentication=yes
  -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}"
  -o BatchMode=yes
  -o StrictHostkeyChecking=no
)
CONCURRENCY="${CONCURRENCY:-16}"
# -----------------------------------------------------------------------------

OUT_DIR="${HOME}/.local/etc"
STATUS_DIR="${HOME}/.local/state"
DUNE_OUT_FILE="${OUT_DIR}/dunegpvm"
DUNE_STATUS_FILE="${STATUS_DIR}/dunegpvm_status.json"

mkdir -p "$OUT_DIR" "$STATUS_DIR"

# Temporary files
if [ "$OS_TYPE" = "macos" ]; then
  DUNE_TMP_CSV="$(mktemp -t dunegpvm_scan)"
else
  DUNE_TMP_CSV="$(mktemp /tmp/dunegpvm_scan.XXXXXX.csv)"
fi
trap 'rm -f "$DUNE_TMP_CSV"' EXIT

timestamp() {
  # OS에 상관없이 ISO 8601 UTC 형식으로 통일 (jq 호환성)
  date -u +"%Y-%m-%d T%H:%M:%S"
}

log() {
	# prefixed log suitable for journald
	echo "$(timestamp) [dunegpvm-scanner] $*"
}

has_kerberos_ticket() {
  # check whether klist exist
  if ! command -v klist >/dev/null 2>&1; then
    return 1
  fi

  # check FNAL.GOV ticket
  if klist 2>/dev/null | grep -Fq "$REALM"; then
    return 0
  else
    return 1
  fi
}

fetch_one() {
	local host="$1"
	local out=""
	local loads=""
	# Try /proc/loadavg
	out=$(ssh ${SSH_OPTS_ARRAY[@]} "${USERNAME}@${host}.${DOMAIN}" 'cat /proc/loadavg')
	if out=$(ssh ${SSH_OPTS_ARRAY[@]} "${USERNAME}@${host}.${DOMAIN}" 'cat /proc/loadavg' 2>/dev/null); then
		# extract first three floats
		#loads=$(echo "$out" | grep -oE '[0-9]+(\.[0-9]+)?' | head -n3 | tr '\n' ' ' | sed 's\ $\\') # it works only in Linux
    loads=$(echo "$out" | grep -oE '[0-9]+(\.[0-9]+)?' | head -n3 | xargs)
    [ -n "$loads" ] && echo "${host},$(echo $loads | awk '{print $1","$2","$3}'),/proc/loadavg" >> "$DUNE_TMP_CSV" && return 0
	fi

	# fallback -> unreachable
	printf "%s,, ,UNREACHABLE\n" "${host}" >> "$DUNE_TMP_CSV"
	return 1
}


#
#
#  Script entry
#
#

# Check Kerberos ticket presence
if ! has_kerberos_ticket; then
	log "No valid Kerberos ticket for principal ${PRINCIPAL}. Skipping scan; writing -1 to ${DUNE_OUT_FILE}."
	echo "-1" > "${DUNE_OUT_FILE}"
	# Update JSON status
	jq -n --arg ts "$(timestamp)" \
	      --arg note "no_kerberos_ticket" \
	      '{timestamp:$ts, selected_index:-1, note:$note, loads:[]} ' > "${DUNE_STATUS_FILE}" 2>/dev/null || \
	      echo "{\"timestamp\":\"$(timestamp)\",\"selected_index\":-1,\"note\":\"no_kerberos_ticket\",\"loads\":[]}" > "${DUNE_STATUS_FILE}"
	exit 0
fi

log "Kerberos ticket present for ${PRINCIPAL}. Starting load scan..."

echo "host, load1, load5, load15, source" > "$DUNE_TMP_CSV"

# ############################################################################
# 수정된 부분: Bash 버전을 확인하여 동시성 제어 분기
# ############################################################################

# Bash 버전이 4.3 이상인지 확인 (wait -n 지원 여부)
# BASH_VERSINFO[0] = Major, BASH_VERSINFO[1] = Minor
if [[ -n "${BASH_VERSINFO:-}" && ${BASH_VERSINFO[0]} -ge 4 && ${BASH_VERSINFO[1]} -ge 3 ]]; then
  # --- 최신 Bash (>= 4.3) : 'wait -n' 사용 ---
  log "Using 'wait -n' (Bash ${BASH_VERSION})."
  jobs_in_flight=0
  for i in $(seq -w "$DUNEGPVM_START" "$DUNEGPVM_END"); do
    host="${HOST_PREFIX}${i}"
    log "Fetching information from $host"
    fetch_one "$host" &

    jobs_in_flight=$((jobs_in_flight+1))
    if [ "$jobs_in_flight" -ge "$CONCURRENCY" ]; then
      wait -n
      jobs_in_flight=$((jobs_in_flight-1))
    fi
  done

else
  # --- 구형 Bash (< 4.3) : PID 목록 관리 (macOS 기본값) ---
  log "Using PID list (Bash ${BASH_VERSION}). 'wait -n' not supported."
  pids=() # 실행된 작업의 PID를 저장할 배열

  for i in $(seq -w "$DUNEGPVM_START" "$DUNEGPVM_END"); do
    host="${HOST_PREFIX}${i}"
    log "Fetching information from $host"
    fetch_one "$host" &
    pids+=($!) # 방금 실행한 백그라운드 작업의 PID를 배열에 추가

    # 실행 중인 작업 수가 CONCURRENCY에 도달하면
    if [ ${#pids[@]} -ge "$CONCURRENCY" ]; then
      # 배열의 첫 번째(가장 오래된) 작업이 끝날 때까지 대기
      wait "${pids[0]}"
      # 완료된 PID를 배열에서 제거
      pids=("${pids[@]:1}")
    fi
  done

  # 루프가 끝난 후 배열에 남은 모든 작업 대기
  [ ${#pids[@]} -gt 0 ] && wait "${pids[@]}"
fi

# ############################################################################
# 수정 종료
# ############################################################################


# wait remaining (모든 작업이 끝날 때까지 대기)
wait || true

log "Fetched average load information from all servers."

# Now parse CSV and pick host with minimal 15-min load (3rd numeric column)
# Keep entries with numeric 15-min value
# Format: host, load1, loaf5, load15, source
selected_host=""
selected_index=-1
selected_val=""

# Create a temporary file in a portable way
if [ "$OS_TYPE" = "macos" ]; then
  # On macOS, -t is the most reliable way. It creates the file in the proper temp dir.
  # The argument is a prefix for the filename.
  candfile="$(mktemp -t dunegpvm_cand)"
else
  # The original syntax works perfectly on Linux.
  candfile="$(mktemp /tmp/dunegpvm_cand.XXXXXX)"
fi
trap 'rm -f "$candfile" "$DUNE_TMP_CSV"' EXIT # candfile도 trap에 추가

# Read CSV skipping header
tail -n +2 "$DUNE_TMP_CSV" | while IFS=, read -r host l1 l5 l15 src; do
  # trim spaces
  l15_trim="$(echo "$l15" | tr -d '[:space:]')"
  # check numeric
  if echo "$l15_trim" | grep -Eq '^[0-9]+(\.[0-9]+)?'; then
	  # store as "value host"
	  printf "%s %s\n" "$l15_trim" "$host"
  fi
done > "$candfile" || true

if [ -s "$candfile" ]; then
	# sort numerically ascending and take first (smallest)
	read -r selected_val selected_host < <(sort -n "$candfile" | head -n1)
	
	# (수정) BASH_REMATCH를 사용하여 호스트 이름에서 인덱스 추출
	if [[ "$selected_host" =~ ([0-9]+)$ ]]; then
    selected_index="${BASH_REMATCH[1]}"
    # 0으로 시작하는 경우(e.g., 01) 10진수로 변환 (e.g., 1)
    selected_index=$((10#$selected_index)) 
	else
		# fallback: -1 if can't parse
		selected_index=-1
	fi
else
	# no reachable hosts with numeric loads
	selected_index=-1
fi

# write the chosen index (or -1) to DUNE_OUT_FILE
echo "${selected_index}" > "${DUNE_OUT_FILE}"
log "Selected index ${selected_index} (15-min load: ${selected_val:-N/A}). Written to ${DUNE_OUT_FILE}."

# also log a compact summary to journal
log "Scan complete. selected_index=${selected_index} selected_val=${selected_val:-N/A}."
echo "Scan complete. selected_index=${selected_index} selected_val=${selected_val:-N/A}."

exit 0
