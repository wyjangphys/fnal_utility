#!/bin/sh

# 초기 변수 설정
SHELL_STARTUP_SCRIPT="$HOME/.bashrc"
DEFAULT_DEST="$HOME/.local"
FILES="setup-appt-build.sh|setup-dune.sh|setup-dune-alma9.sh|setup-genie-bdm.sh|setup-samweb.sh|utility.sh|setup-appt.sh|setup-dune-sl7.sh|setup-icarus-sl7.sh|setup-vnc.sh|dunegpvm_ssh_wrapper.sh"
GPVM_SCANNER_FILES="gpvm-scanner/dunegpvm-scan.service|gpvm-scanner/dunegpvm-scan.sh|gpvm-scanner/dunegpvm-scan.timer"
ALIASES_FIRST_LINE='#=_=_=_=_=_= added by fnal_utility (do not remove) =_=_=_=_=_=_='
ALIASES_LAST_LINE='#=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_=_='

check_shell() {
  case $SHELL in
    */sh)
      SHELL_STARTUP_SCRIPT="$HOME/.profile"
      ;;
    */bash)
      SHELL_STARTUP_SCRIPT="$HOME/.bashrc"
      ;;
    */zsh)
      SHELL_STARTUP_SCRIPT="$HOME/.zshrc"
      ;;
    *)
      ;;
  esac
}

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
  if grep -Fq -- "$ALIASES_FIRST_LINE" "$SHELL_STARTUP_SCRIPT"; then
    echo "ALIASES block already exists in $SHELL_STARTUP_SCRIPT."
  else
    echo "\n%s\n" "$ALIASES" >> "$SHELL_STARTUP_SCRIPT"
    echo "ALIASES block added to $SHELL_STARTUP_SCRIPT."
  fi
}

remove_alias_block() {
  if grep -Fq -- "$ALIASES_FIRST_LINE" "$SHELL_STARTUP_SCRIPT" ; then
    echo "ALIASES block found."
    cp -v "$SHELL_STARTUP_SCRIPT" "${SHELL_STARTUP_SCRIPT}.bak" || echo "Failed to generate backup file."
    FIRST_LINE=$(echo '%s\n' "$ALIASES" | head -n1)
    LAST_LINE=$(echo '%s\n' "$ALIASES" | tail -n1)
    sed -i "/$(echo '%s' "$FIRST_LINE" | sed 's/[^^]/[&]/g')/,/$(echo '%s' "$LAST_LINE" | sed 's/[^^]/[&]/g')/d" "$SHELL_STARTUP_SCRIPT"
    echo "ALIASES block removed from ${SHELL_STARTUP_SCRIPT}. Backup file ${SHELL_STARTUP_SCRIPT}.bak made."
  fi
}

stop_gpvm_scanner_daemon() {
  systemctl --user stop dunegpvm-scan.timer
  systemctl --user stop dunegpvm-scan.service
}

print_instruction() {
  printf "To use the dunegpvm scanner daemon, first reload the daemons: \n"
  printf "     $ systemctl --user daemon-reload\n"
  printf "To start the dunegpvm scanner daemon (one time): \n"
  printf "     $ systemctl --user start .config/systemd/user/dunegpvm-scan.timer\n"
  printf "     $ systemctl --user start .config/systemd/user/dunegpvm-scan.service\n"
  printf "To start the dunegpvm scanner daemon automatically every login: \n"
  printf "     $ systemctl --user enable .config/systemd/user/dunegpvm-scan.timer\n"
  printf "     $ systemctl --user enable .config/systemd/user/dunegpvm-scan.service\n"
}

check_shell

# 실제 동작
case "$MODE" in
  install)
    printf "Installing fnal_utility scripts to $DESTINATION"
    copy_files
    add_alias_block
    print_instruction
    printf "fnal_utility scripts are installed successfully."
    ;;
  uninstall)
    printf "Uninstalling fnal_utility scripts from $DESTINATION"
    remove_files
    remove_alias_block
    printf "fnal_utility scripts are removed successfully."
    ;;
  *)
    printf "Unknown mode"
    exit 1
    ;;
esac

