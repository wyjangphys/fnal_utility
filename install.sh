#!/bin/bash

# 초기 변수 설정
BASHRC="$HOME/.bashrc"
DEFAULT_DEST="$HOME/.local"
FILES="setup-appt-build.sh|setup-dune.sh|setup-dune-alma9.sh|setup-genie-bdm.sh|setup-samweb.sh|utility.sh|setup-appt.sh|setup-dune-sl7.sh|setup-icarus-sl7.sh|setup-vnc.sh|dunegpvm_ssh_wrapper.sh"
GPVM_SCANNER_FILES="gpvm-scanner/dunegpvm-scan.service|gpvm-scanner/dunegpvm-scan.sh|gpvm-scanner/dunegpvm-scan.timer"
ALIASES_FIRST_LINE='#=_=_=_=_=_= added by fnal_utility (do not remove) =_=_=_=_=_=_='
ALIASES_LAST_LINE='#=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_='

generate_aliases(){
cat <<EOF
$ALIASES_FIRST_LINE
export FNAL_UTIL_ROOT="${DESTINATION}/../"
alias appt=". $DESTINATION/bin/setup-appt.sh"
alias appt_build=". $DESTINATION/bin/setup-appt-build.sh"
alias setup-icarus=". $DESTINATION/bin/setup-icarus-sl7.sh"
alias setup-dune=". $DESTINATION/bin/setup-dune.sh"
alias setup-genie-bdm=". $DESTINATION/bin/setup-genie-bdm.sh"
alias setup-vnc=". $DESTINATION/bin/setup-vnc.sh"
alias clearcert="rm -fv /tmp/x509up_u\$(id -u)"
source $DESTINATION/bin/dunegpvm_ssh_wrapper.sh
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
  mkdir -p "$DESTINATION/bin"
  mkdir -p "$DESTINATION/etc"
  mkdir -p "$DESTINATION/state"
  mkdir -p "$HOME/.config/systemd/user"

  for file in $FILES_LIST; do
    cp -v "$file" "$DESTINATION/bin/" || echo "Failed to copy $file"
  done
  cp -v gpvm-scanner/dunegpvm-scan.sh $DESTINATION/bin/
  cp -v gpvm-scanner/dunegpvm-scan.service $HOME/.config/systemd/user/
  cp -v gpvm-scanner/dunegpvm-scan.timer $HOME/.config/systemd/user/
}

remove_files() {
  for file in $FILES_LIST; do
    rm -fv "$DESTINATION/$file" || echo "Failed to remove $file"
  done
  rm -fv $DESTINATION/bin/dunegpvm-scan.sh
  rm -fv $HOME/.config/systemd/user/dunegpvm-scan.service
  rm -fv $HOME/.config/systemd/user/dunegpvm-scan.timer
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
    echo "fnal_utility scripts are installed successfully."
    ;;
  uninstall)
    echo "Uninstalling fnal_utility scripts from $DESTINATION"
    remove_files
    remove_alias_block
    echo "fnal_utility scripts are removed successfully."
    ;;
  *)
    echo "Unknown mode"
    exit 1
    ;;
esac

