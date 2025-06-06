#!/bin/sh
. $FNAL_UTIL_ROOT/bin/utility.sh

if [ -f /etc/os-release ] ; then
  . /etc/os-release
  echo "Setting Custom GENIE with BDM plugin ... "
  if [ "$ID" = "almalinux" ] && [ "${VERSION_ID#9}" != "$VERSION_ID" ] ; then
    run_command "Setting GCC 8.2.0 ... " setup gcc v8_2_0
  elif [ "$ID" = "scientific" ] && [ "${VERSION_ID#7}" != "$VERSION_ID" ] ; then
    run_command "Setting GCC 12.2.0 ... " spack load gcc@12.2.0
  else
    echo "Running on other Linux: $ID $VERSION_ID"
  fi
  run_command "GENIE=/exp/dune/app/users/wyjang/genie/3.02.04" export GENIE=/exp/dune/app/users/wyjang/genie/3.02.04
  run_command "PATH=\$GENIE/bin:\$PATH" export PATH=$GENIE/bin:$PATH
  run_command "LD_LIBRARY_PATH=\$GENIE/lib:\$LD_LIBRARY_PATH" export LD_LIBRARY_PATH=$GENIE/lib:$LD_LIBRARY_PATH
else
  echo "Cannot determine OS: /etc/os-release not found"
fi
