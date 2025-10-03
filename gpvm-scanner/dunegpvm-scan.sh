#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------- Configuration ----------------------------
USERNAME=${USERNAME:-${USER:-$(whoami)}}
REALM="${REALM:-FNAL.GOV}"
PRINCIPAL="${PRINCIPAL:-${USERNAME}@${REALM}}"

HOST_PREFIX="${HOST_PREFIX:-dunegpvm}"
DOMAIN="${DOMAIN:-fnal.gov}"
DUNEGPVM_START="${DUNEGPVM_START:-1}"
DUNEGPVM_END="${DUNEGPVM_END:-16}"
#ICARUSGPVM_START="${ICARUSGPVM_START:-1}"
#ICARUSGPVM_END="${ICARUSGPVM_END:-8}"
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-6}"
SSH_OPTS="-o ConnectTimeout=${SSH_CONNECT_TIMEOUT} -o BatchMode=yes -o StrictHostkeyChecking=no -tt"
CONCURRENCY="${CONCURRENCY:-24}"
# -----------------------------------------------------------------------------

OUT_DIR="${HOME}/.local/etc"
STATUS_DIR="${HOME}/.local/state"
DUNE_OUT_FILE="${OUT_DIR}/dunegpvm"
#ICARUS_OUT_FILE="${OUT_DIR}/icarusgpvm"
DUNE_STATUS_FILE="${STATUS_DIR}/dunegpvm_status.json"
#ICARUS_STATUS_FILE="${STATUS_DIR}/icarusgpvm_status.json"

mkdir -p "$OUT_DIR" "$STATUS_DIR"

# Temporary files
DUNE_TMP_CSV="$(mktemp /tmp/dunegpvm_scan.XXXXXX.csv)"
#ICARUS_TMP_CSV="$(mktemp /tmp/icarusgpvm_scan.XXXXXX.csv)"
#trap 'rm -f "$DUNE_TMP_CSV"' EXIT
#trap 'rm -f "$DUNE_TMP_CSV" "$ICARUS_TMP_CSV"' EXIT

timestamp() {
	date --iso-8601=seconds
}

log() {
	# prefixed log suitable for journald
	echo "$(timestamp) [dunegpvm-scanner] $*"
}

has_kerberos_ticket() {
	klist 2>/dev/null | grep -q $REALM
}

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

# Concurrency semaphore
jobs_in_flight=0

fetch_one() {
	local host="$1"
	local out=""
	local loads=""
	# Try /proc/loadavg
	if out=$(ssh $SSH_OPTS "${USERNAME}@${host}${DOMAIN}" 'cat /proc/loadavg' 2>/dev/null); then
		# extract first three floats
		loads=$(echo "$out" | grep -oE '[0-9]+(\.[0-9]+)?' | head -n3 | tr '\n' ' ' | sed 's\ $\\')
      		[ -n "$loads" ] && echo "${host},$(echo $loads | awk '{print $1","$2","$3}'),/proc/loadavg" >> "$DUNE_TMP_CSV" && return 0
		#if [ -n "$loads" ]; then
	#		echo "%s,%s,/proc/loadavg\n" "${host}" "$(echo $loads | awk '{print \"$1\", \"$2\", \"$3\"}')" >> "$DUNE_TMP_CSV"
	#		return 0
	#	fi
	fi

	# fallback -> unreachable
	printf "%s,, ,UNREACHABLE\N" "${host}" >> "$TMP_CSV"
	return 1
}

# Launch parallel jobs
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

# wait remaining
wait

log "Fetched average load information from all servers."

# Now parse CSV and pick host with minimal 15-min load (3rd numeric column)
# Keep entries with numeric 15-min value
# Format: host, load1, loaf5, load15, source
selected_host=""
selected_index=-1
selected_val=""

# Read CSV skipping header
tail -n +2 "$DUNE_TMP_CSV" | while IFS=, read -r host l1 l5 l15 src; do
  # trim spaces
  l15_trim="$(echo "$l15" | tr -d '[:space:]')"
  # check numeric
  if echo "$l15_trim" | grep -Eq '^[0-9]+(\.[0-9]+)?'; then
	  # store as "value host"
	  printf "%s %s\n" "$l15_trim" "$host"
  fi
done > /tmp/dunegpvm_candidates.$$ || true

if [ -s /tmp/dunegpvm_candidates.$$ ]; then
	# sort numerically ascending and take first (smallest)
	read -r selected_val selected_host < <(sort -n /tmp/dunegpvm_candidates.$$ | head -n1)
	rm -f /tmp/dunegpvm_candidates.$$
	# extract index digits from host name; accept both dunegpvm01 etc or dunegpvm1
	if [[ "$selected_host" =~ ([0-9]+)$ ]]; then
		selected_index="${BASH_REMATCH[1]}"
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
log "Scan complete. selected_index=${selected_index} selected_val=${selected_val:-N/A}. Status file: ${DUNE_STATUS_FILE}"

exit 0
