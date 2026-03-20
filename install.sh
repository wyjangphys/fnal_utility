#!/bin/sh

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

# 초기 변수 설정
SHELL_STARTUP_SCRIPT="$HOME/.bashrc"
DEFAULT_DEST="$HOME/.local"
FILES="setup-appt-build.sh|setup-dune.sh|setup-dune-alma9.sh|setup-genie-bdm.sh|setup-g4.sh|setup-samweb.sh|utility.sh|setup-appt.sh|setup-dune-sl7.sh|setup-icarus.sh|setup-icarus-alma9.sh|setup-icarus-sl7.sh|setup-vnc.sh|gpvm_ssh_wrapper.sh"
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
alias setup-spack=". /nashome/w/wyjang/.local/bin/setup-spack.sh"
alias setup-g4=". /nashome/w/wyjang/.local/bin/setup-g4.sh"
alias setup-icarus=". $DESTINATION/bin/setup-icarus-sl7.sh"
alias setup-dune=". $DESTINATION/bin/setup-dune.sh"
alias setup-genie-bdm=". $DESTINATION/bin/setup-genie-bdm.sh"
alias setup-vnc=". $DESTINATION/bin/setup-vnc.sh"
alias clearcert="rm -fv /tmp/x509up_u\$(id -u)"
source $DESTINATION/bin/gpvm_ssh_wrapper.sh
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
FILES_LIST=$(
  IFS='|'
  set -- $FILES
  echo "$@"
)

# 공통 함수 (필요시)
copy_files() {
  mkdir -p "$DESTINATION/bin"
  mkdir -p "$DESTINATION/etc"
  mkdir -p "$DESTINATION/state"
  mkdir -p "$HOME/.config/systemd/user"

#removed for non-fermilab gpvm computers
#  cp -v ./.bashrc $DESTINATION/bin/
#  if [ -f $HOME/.bashrc ]; then
#    mv $HOME/.bashrc $HOME/.bashrc.bak
#  fi
#  ln -s $DESTINATION/bin/.bashrc $HOME/.bashrc
  for file in $FILES_LIST; do
    cp -v "$file" "$DESTINATION/bin/" || echo "Failed to copy $file"
  done
  cp -v vim/indent/fhicl.vim ~/.vim/indent/fhicl.vim
  if [ "$OS_TYPE" = "linux" ]; then
    cp -v gpvm-scanner/gpvm-scanner.sh $DESTINATION/bin/
    cp -v gpvm-scanner/dunegpvm-scan.service $HOME/.config/systemd/user/
    cp -v gpvm-scanner/dunegpvm-scan.timer $HOME/.config/systemd/user/
    cp -v gpvm-scanner/icarusgpvm-scan.service $HOME/.config/systemd/user/
    cp -v gpvm-scanner/icarusgpvm-scan.timer $HOME/.config/systemd/user/
  elif [ "$OS_TYPE" = "macos" ]; then
    cp -v gpvm-scanner/gpvm-scanner.sh $DESTINATION/bin/
    cp -v gpvm-scanner/com.user.gpvm-scanner.plist $HOME/Library/LaunchAgents/
  fi
}

remove_files() {
  for file in $FILES_LIST; do
    rm -fv "$DESTINATION/$file" || echo "Failed to remove $file"
  done
  if [ "$OS_TYPE" = "linux" ]; then
    rm -fv $DESTINATION/bin/gpvm-scanner.sh
    rm -fv $HOME/.config/systemd/user/dunegpvm-scan.service
    rm -fv $HOME/.config/systemd/user/dunegpvm-scan.timer
    rm -fv $HOME/.config/systemd/user/icarusgpvm-scan.service
    rm -fv $HOME/.config/systemd/user/icarusgpvm-scan.timer
  elif [ "$OS_TYPE" = "macos" ]; then
    rm -fv $DESTINATION/bin/gpvm-scanner.sh
    rm -fv $HOME/Library/LaunchAgents/com.user.gpvm-scanner.plist
  fi
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
  if [ "$OS_TYPE" = "linux" ]; then
    systemctl --user stop dunegpvm-scan.timer
    systemctl --user stop dunegpvm-scan.service
  elif [ "$OS_TYPE" = "macos" ]; then
    launchctl disable gui/$(id -u)/com.user.gpvm-scanner
    printf "launchctl agent com.user.gpvm-scanner disabled.\n"
    printf "To re-enable, use command\n"
    printf "     launchctl enable gui/$(id -u)/com.user.gpvm-scanner\n"
  fi
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
  printf "\n"
  printf "For macOS, to start launchd service,\n"
  printf "     $ launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.gpvm-scanner.plist\n"
  printf "   in case you already bootstraped, \n"
  printf "     $ launchctl kickstart -k gui/$(id -u)/com.user.gpvm-scanner\n"
  printf "To stop the launchd service,\n"
  printf "     $ launchctl disable gui/$(id -u)/com.user.gpvm-scanner\n"
  printf "To restart the launchd service,\n"
  printf "     $ launchctl enable gui/$(id -u)/com.user.gpvm-scanner\n"
  printf "To stop and unregister the service,\n"
  printf "     $ launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.gpvm-scanner.plist\n"
  printf "To see the logs,\n"
  printf "     $ tail -n 200 ~/Library/Logs/gpvm-scanner.out.log\n"
  printf "     $ tail -n 200 ~/Library/Logs/gpvm-scanner.err.log\n"
}

check_shell

# 실제 동작
case "$MODE" in
  install)
    printf "Installing fnal_utility scripts to $DESTINATION\n"
    copy_files
    add_alias_block
    print_instruction
    printf "fnal_utility scripts are installed successfully.\n"
    ;;
  uninstall)
    printf "Uninstalling fnal_utility scripts from $DESTINATION\n"
    remove_files
    remove_alias_block
    printf "fnal_utility scripts are removed successfully.\n"
    ;;
  *)
    printf "Unknown mode"
    exit 1
    ;;
esac

