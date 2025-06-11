#!/bin/sh

# Version table
ROOT_VERSION=6.28.12
GEANT_VERSION=10.6.1
CMAKE_VERSION=3.27.7
GCC_VERSION=12.2.0
FIFEUTILS_VERSION=3.7.4

# Start loading packages
echo "Running on Alma Linux 9"
. /cvmfs/larsoft.opensciencegrid.org/spack-packages/setup-env.sh
# check spack.readthedocs.io/en/latest/basic_usage.html for the detailed usage.
run_command "Setting root $ROOT_VERSION via spack" spack load root@$ROOT_VERSION
run_command "Setting geant4 $GEANT_VERSION via spack" spack load geant4@$GEANT_VERSION
run_command "Setting geant4 data $GEANT_VERSION via spack" spack load geant4-data@$GEANT_VERSION
run_command "Setting cmake $CMAKE_VERSION via spack" spack load cmake@$CMAKE_VERSION
run_command "Setting gcc $GCC_VERSION via spack" spack load gcc@$GCC_VERSION
run_command "Setting fife-utils $FIFEUTILS_VERSION via spack" spack load fife-utils@$FIFEUTILS_VERSION
run_command "Setting r-m-dd-config via spack" spack load r-m-dd-config experiment=dune
echo "Setting up grid access authorization"
run_command "└ Getting token from vaultserver" get_bearer_token dune;export BEARER_TOKEN_FILE=/run/user/`id -u`/bt_u`id -u`
run_command "Setting samweb" set_samweb dune
run_command "Setting \$PATH variable" export PATH=/exp/dune/app/users/wyjang/dune/edep-sim/edep-gcc-11-x86_64-redhat-linux/bin/edep-sim:$PATH
run_command "Setting \$LD_LIBRARY_PATH variable" export LD_LIBRARY_PATH=/exp/dune/app/users/wyjang/dune/edep-sim/edep-gcc-11-x86_64-redhat-linux/lib:$LD_LIBRARY_PATH
set_prompt
