#!/bin/sh
. $FNAL_UTIL_ROOT/bin/utility.sh

EXPAT_VERSION=2.5.0
GEANT4_VERSION=10.6.1

. /cvmfs/larsoft.opensciencegrid.org/spack-packages/setup-env.sh
case $EXPERIMENT in
  "dune")
    ;;
  "icarus")
    EXPAT_HASH="/63bs7em"
    GEANT4_HASH="/r2dcnvb"
    ;;
  *)
    printf "Unsupported environment EXPERIMENT=$EXPERIMENT\n"
    exit 1
    ;;
esac
run_command "Setting expat $EXPAT_VERSION via spack" spack load $EXPAT_HASH
run_command "Setting geant4 $GEANT4_VERSION via spack" spack load $GEANT4_HASH
run_command "Soucing geant4.sh ..." source $(spack location -i $GEANT4_HASH)/bin/geant4.sh
#run_command "Setting root $ROOT_VERSION vis spack" spack load root@$ROOT_VERSION
export Geant4_DIR=$(spack location -i $GEANT4_HASH)/lib64/Geant4-$GEANT4_VERSION
export G4DIR=$Geant4_DIR
export CMAKE_PREFIX_PATH=$(spack location -i $GEANT4_HASH):$(spack location -i $EXPAT_HASH):$CMAKE_PREFIX_PATH
