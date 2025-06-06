#!/bin/sh
. $FNAL_UTIL_ROOT/bin/utility.sh
. $FNAL_UTIL_ROOT/bin/setup-samweb.sh

if [ -f /etc/os-release ]; then
  . /etc/os-release

  # when os is almalinux and the version number starts with 9,
  if [ "$ID" = "almalinux" ] && [ "${VERSION_ID#9}" != "$VERSION_ID" ] ; then
    . $FNAL_UTIL_ROOT/bin/setup-dune-alma9.sh
  elif [ "$ID" = "scientific" ] && [ "${VERSION_ID#7}" != "$VERSION_ID" ] ; then
    . $FNAL_UTIL_ROOT/bin/setup-dune-sl7.sh
  else
    echo "Running on other Linux: $ID $VERSION_ID"
  fi
else
  echo "Cannot determine OS: /etc/os-release not found"
fi

alias ls="ls --color"
export appdir="/exp/dune/app/users/wyjang"
export datadir="/exp/dune/data/users/wyjang"
