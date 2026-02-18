#!/bin/sh
. $FNAL_UTIL_ROOT/bin/utility.sh

EXPAT_VERSION=2.5.0
GEANT4_VERSION=10.6.1

. /cvmfs/larsoft.opensciencegrid.org/spack-packages/setup-env.sh
case $EXPERIMENT in
  "dune")
    ;;
  "icarus")
    EXPAT_VERSION="2.5.0%gcc@11.4.1 arch=linux-almalinux9-x86_64_v3"
    GEANT4_VERSION="10.6.1%gcc@12.2.0 arch=linux-almalinux9-x86_64_v3"
    ;;
  *)
    printf "Unsupported environment EXPERIMENT=$EXPERIMENT\n"
    exit 1
    ;;
esac
run_command "Setting expat $EXPAT_VERSION via spack" spack load expat@${EXPAT_VERSION}
run_command "Setting geant4 $GEANT4_VERSION via spack" spack load geant4@${GEANT4_VERSION}
run_command "Soucing geant4.sh ..." source $(spack location -i geant4@${GEANT4_VERSION})/bin/geant4.sh
#run_command "Setting root $ROOT_VERSION vis spack" spack load root@$ROOT_VERSION
export Geant4_DIR=$(spack location -i geant4@${GEANT4_VERSION})/lib64/Geant4-$GEANT4_VERSION
export G4DIR=$Geant4_DIR
export CMAKE_PREFIX_PATH=$(spack location -i geant4@$GEANT4_VERSION):$(spack location -i expat@2.5.0):$CMAKE_PREFIX_PATH
