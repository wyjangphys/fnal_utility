#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------- Configuration ----------------------------
USERNAME=${USERNAME:-${USER:-$(whoami)}}
REALM="${REALM:-FNAL.GOV}"
PRINCIPAL="${PRINCIPAL:-${USERNAME}@${REALM}}"

HOST_PREFIX="${HOST_PREFIX:-gpvm}"
DOMAIN="${DOMAIN:-fnal.gov}"
ICARUSGPVM_START="${ICARUSGPVM_START:-1}"
ICARUSGPVM_END="${ICARUSGPVM_END:-6}"
#ICARUSGPVM_START="${ICARUSGPVM_START:-1}"
#ICARUSGPVM_END="${ICARUSGPVM_END:-8}"
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-6}"
SSH_OPTS="-o ConnectTimeout=${SSH_CONNECT_TIMEOUT} -o BatchMode=yes -o StrictHostkeyChecking=no -tt"
CONCURRENCY="${CONCURRENCY:-24}"
# -----------------------------------------------------------------------------

OUT_DIR="${HOME}/.local/etc"
STATUS_DIR="${HOME}/.local/state"
ICARUS_OUT_FILE="${OUT_DIR}/icarusgpvm"
ICARUS_STATUS_FILE="${STATUS_DIR}/icarusgpvm_status.json"

mkdir -p "$OUT_DIR" "$STATUS_DIR"

# Temporary files
ICARUS_TMP_CSV="$(mktemp /tmp/icarusgpvm_scan.XXXXXX.csv)"
trap 'rm -f "$ICARUS_TMP_CSV"' EXIT

timestamp() {
	date --iso-8601=seconds
}

log() {
	# prefixed log suitable for journald
	echo "$(timestamp) [gpvm-scanner] $*"
}

has_kerberos_ticket() {
	klist 2>/dev/null | grep -q $REALM
}

# Check Kerberos ticket presence
if ! has_kerberos_ticket; then
	log "No valid Kerberos ticket for principal ${PRINCIPAL}. Skipping scan; writing -1 to ${ICARUS_OUT_FILE}."
	echo "-1" > "${ICARUS_OUT_FILE}"
	# Update JSON status
	jq -n --arg ts "$(timestamp)" \
	      --arg note "no_kerberos_ticket" \
	      '{timestamp:$ts, selected_index:-1, note:$note, loads:[]} ' > "${ICARUS_STATUS_FILE}" 2>/dev/null || \
	      echo "{\"timestamp\":\"$(timestamp)\",\"selected_index\":-1,\"note\":\"no_kerberos_ticket\",\"loads\":[]}" > "${ICARUS_STATUS_FILE}"
	exit 0
fi

log "Kerberos ticket present for ${PRINCIPAL}. Starting load scan..."

echo "host, load1, load5, load15, source" > "$ICARUS_TMP_CSV"

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
      		[ -n "$loads" ] && echo "${host},$(echo $loads | awk '{print $1","$2","$3}'),/proc/loadavg" >> "$ICARUS_TMP_CSV" && return 0
		#if [ -n "$loads" ]; then
	#		echo "%s,%s,/proc/loadavg\n" "${host}" "$(echo $loads | awk '{print \"$1\", \"$2\", \"$3\"}')" >> "$ICARUS_TMP_CSV"
	#		return 0
	#	fi
	fi

	# fallback -> unreachable
	printf "%s,, ,UNREACHABLE\N" "${host}" >> "$ICARUS_TMP_CSV"
	return 1
}

# Launch parallel jobs
for i in $(seq -w "$ICARUSGPVM_START" "$ICARUSGPVM_END"); do
  padded_i=$(printf "%02d" "$i")
	host="${HOST_PREFIX}${padded_i}"
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
tail -n +2 "$ICARUS_TMP_CSV" | while IFS=, read -r host l1 l5 l15 src; do
  # trim spaces
  l15_trim="$(echo "$l15" | tr -d '[:space:]')"
  # check numeric
  if echo "$l15_trim" | grep -Eq '^[0-9]+(\.[0-9]+)?'; then
	  # store as "value host"
	  printf "%s %s\n" "$l15_trim" "$host"
  fi
done > /tmp/icarus_gpvm_candidates.$$ || true

if [ -s /tmp/icarus_gpvm_candidates.$$ ]; then
	# sort numerically ascending and take first (smallest)
	read -r selected_val selected_host < <(sort -n /tmp/icarus_gpvm_candidates.$$ | head -n1)
	rm -f /tmp/icarus_gpvm_candidates.$$
	# extract index digits from host name; accept both gpvm01 etc or icarusgpvm1
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

# write the chosen index (or -1) to ICARUS_OUT_FILE
echo "${selected_index}" > "${ICARUS_OUT_FILE}"
log "Selected index ${selected_index} (15-min load: ${selected_val:-N/A}). Written to ${ICARUS_OUT_FILE}."

# also log a compact summary to journal
log "Scan complete. selected_index=${selected_index} selected_val=${selected_val:-N/A}. Status file: ${ICARUS_STATUS_FILE}"

exit 0
