#!/bin/sh

# 초기 변수 설정
BASHRC="$HOME/.bashrc"
DEFAULT_DEST="$HOME/.local/bin"
FILES="setup-appt-build.sh|setup-dune.sh|setup-dune-alma9.sh|setup-genie-bdm.sh|setup-samweb.sh|utility.sh|setup-appt.sh|setup-dune-sl7.sh|setup-icarus-sl7.sh|setup-vnc.sh"
ALIASES_FIRST_LINE='#=_=_=_=_=_= added by fnal_utility (do not remove) =_=_=_=_=_=_='
ALIASES_LAST_LINE='#=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_='

generate_aliases(){
cat <<EOF
$ALIASES_FIRST_LINE
export FNAL_UTIL_ROOT="${DESTINATION}/../"
alias appt="source $DESTINATION/setup-appt.sh"
alias appt_build="source $DESTINATION/setup-appt-build.sh"
alias set-icarus="source $DESTINATION/setup-icarus-sl7.sh"
alias set-dune="source $DESTINATION/setup-dune.sh"
alias set-genie-bdm="source $DESTINATION/setup-genie-bdm.sh"
alias clearcert="rm -fv /tmp/x509up_u\$(id -u)"
$ALIASES_LAST_LINE

EOF
}

# 인수 체크
MODE=""
DESTINATION="$DEFAULT_DEST"
if [ "$1" = "uninstall" ]; then
  MODE="uninstall"
  if [ -n "$2" ]; then
    DESTINATION="$2"
  fi
elif [ -n "$1" ]; then
  MODE="install"
  DESTINATION="$1"
else
  MODE="install"
fi

ALIASES="$(generate_aliases)"

# 파일 목록 분리
IFS='|'
set -- $FILES
FILES_LIST="$@"
unset IFS

# 공통 함수 (필요시)
copy_files() {
  mkdir -p "$DESTINATION"
  for file in $FILES_LIST; do
    cp -v "$file" "$DESTINATION/" || echo "Failed to copy $file"
  done
}

remove_files() {
  for file in $FILES_LIST; do
    rm -fv "$DESTINATION/$file" || echo "Failed to remove $file"
  done
}

add_alias_block() {
  if grep -Fq -- "$ALIASES_FIRST_LINE" "$BASHRC"; then
    echo "ALIASES block already exists in $BASHRC."
  else
    printf "\n%s\n" "$ALIASES" >> "$BASHRC"
    echo "ALIASES block added to $BASHRC."
  fi
}

remove_alias_block() {
  if grep -Fq -- "$ALIASES_FIRST_LINE" "$BASHRC" ; then
    echo "ALIASES block found."
    cp -v "$BASHRC" "${BASHRC}.bak" || echo "Failed to generate backup file."
    FIRST_LINE=$(printf '%s\n' "$ALIASES" | head -n1)
    LAST_LINE=$(printf '%s\n' "$ALIASES" | tail -n1)
    sed -i "/$(printf '%s' "$FIRST_LINE" | sed 's/[^^]/[&]/g')/,/$(printf '%s' "$LAST_LINE" | sed 's/[^^]/[&]/g')/d" "$BASHRC"
    echo "ALIASES block removed from ${BASHRC}. Backup file ${BASHRC}.bak made."
  fi
}

# 실제 동작
case "$MODE" in
  install)
    echo "Installing fnal_utility scripts to $DESTINATION"
    copy_files
    add_alias_block
    ;;
  uninstall)
    echo "Uninstalling fnal_utility scripts from $DESTINATION"
    remove_files
    remove_alias_block
    ;;
  *)
    echo "Unknown mode"
    exit 1
    ;;
esac

