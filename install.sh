#!/bin/sh
echo $PWD
if [ ! -f $PWD/utility.sh ] ; then
  echo "utility.sh file not found. Re-install the fnal_utility package."
  return 1;
fi

. $PWD/utility.sh

DESTINATION="$HOME/.local/bin"
FILES="setup-appt-build.sh|\
setup-dune.sh|\
setup-genie-bdm.sh|\
setup-samweb.sh|\
utility.sh|\
setup-appt.sh|\
setup-dune-sl7.sh|\
setup-icarus-sl7.sh|\
set-vnc.sh"

IFS='|'
if [ "$1" = "uninstall" ] ; then
  echo "Uninstalling ... "
  if [ -z "$2" ] ; then
    echo "Removing fnal_utility files from the default directory: $DESTINATION"
    for file in $FILES; do
      rm -fv $DESTINATION/$file
    done
  else
    DESTINATION="$2"
    echo "Removing fnal_utility files from the custom directory: $DESTINATION"
    for file in $FILES; do
      rm -fv $DESTINATION/$file
    done
  fi
elif [ -n "$1" ] ; then
  DESTINATION="$1"
  echo "Installing fnal_utility scripts to custom directory: $DESTINATION"
  mkdir -p "$DESTINATION"
  for file in $FILES; do
    cp -v $file $DESTINATION/
  done
else
  echo "Installing fnal_utility scripts to default directory: $DESTINATION"
  mkdir -p "$DESTINATION"
  for file in $FILES; do
    cp -v $file $DESTINATION/
  done
fi

unset IFS
