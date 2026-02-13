#!/bin/sh

# Version table
ROOT_VERSION=6.28.12
GEANT_VERSION=10.6.1
CMAKE_VERSION=3.27.7
IFDHC_VERSION=2.6.20
GCC_VERSION=12.2.0
FIFEUTILS_VERSION=3.7.4

# Start loading packages
echo "Running on Alma Linux 9"
#. /cvmfs/larsoft.opensciencegrid.org/spack-packages/setup-env.sh # This is not work for xrootd protocol access!
. /cvmfs/larsoft.opensciencegrid.org/spack-v0.22.0-fermi/setup-env.sh
# check spack.readthedocs.io/en/latest/basic_usage.html for the detailed usage.
run_command "Setting root $ROOT_VERSION via spack" spack load root@$ROOT_VERSION%gcc@12.2.0 arch=linux-almalinux9-x86_64_v3
#run_command "Setting r-m-dd-config via spack" spack load r-m-dd-config experiment=icarus
run_command "Setting up grid access authorization (submit mode)" get_bearer_token icarus;export BEARER_TOKEN_FILE=/run/user/`id -u`/bt_u`id -u`
run_command "Setting ifdhc via spack" spack load ifdhc@$IFDHC_VERSION
set_prompt

# deprecated or non-used packages
#run_command "Setting geant4 $GEANT_VERSION via spack" spack load geant4@$GEANT_VERSION
#run_command "Setting geant4 data $GEANT_VERSION via spack" spack load geant4-data@$GEANT_VERSION
#run_command "Setting cmake $CMAKE_VERSION via spack" spack load cmake@$CMAKE_VERSION
#run_command "Setting gcc $GCC_VERSION via spack" spack load gcc@$GCC_VERSION
#run_command "Setting fife-utils $FIFEUTILS_VERSION via spack" spack load fife-utils@$FIFEUTILS_VERSION
#run_command "Setting samweb" set_samweb icarus
