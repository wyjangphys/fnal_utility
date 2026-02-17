#!/bin/sh
. $FNAL_UTIL_ROOT/bin/utility.sh
. $FNAL_UTIL_ROOT/bin/setup-samweb.sh

printf "Hello, ${USER}! We're launching setup-dune.sh!\n"
if [ -f /etc/os-release ]; then
  . /etc/os-release

  # when os is almalinux and the version number starts with 9,
  if [ "$ID" = "almalinux" ] && [ "${VERSION_ID#9}" != "$VERSION_ID" ] ; then
    . $FNAL_UTIL_ROOT/bin/setup-dune-alma9.sh
  elif [ "$ID" = "scientific" ] && [ "${VERSION_ID#7}" != "$VERSION_ID" ] ; then
    . $FNAL_UTIL_ROOT/bin/setup-dune-sl7.sh
  else
    printf "Running on other Linux: $ID $VERSION_ID\n"
  fi
else
  printf "Cannot determine OS: /etc/os-release not found\n"
fi

alias ls="ls --color"

# HTCondor related aliases
alias jobsub_q="jobsub_q -G dune --user wyjang"
alias jobsub_fetchlog="jobsub_fetchlog -G dune"
alias jobsub_rm="jobsub_rm -G dune"
