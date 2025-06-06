#!/bin/sh

echo "Running on Alma Linux 9"
run_command "Setting up spack" . /cvmfs/larsoft.opensciencegrid.org/spack-packages/setup-env.sh
# check spack.readthedocs.io/en/latest/basic_usage.html for the detailed usage.
run_command "Setting up root via spack" spack load root@6.28.12
run_command "Setting up geant4 via spack" bash -c 'spack load geant4 && spack load geant4-data'
run_command "Setting up cmake via spack" spack load cmake@3.27.7
run_command "Setting up gcc via spack" spack load gcc@12.2.0
run_command "Setting up fife-utils via spack" spack load fife-utils@3.7.4
run_command "Setting up r-m-dd-config via spack" spack load r-m-dd-config experiment=dune
echo "Setting up grid access authorization"
run_command "Getting token from vaultserver" get_bearer_token dune;export BEARER_TOKEN_FILE=/run/user/`id -u`/bt_u`id -u`
run_command "Setting samweb" set_samweb dune
run_command "Setting \$PATH variable" export PATH=/exp/dune/app/users/wyjang/dune/edep-sim/edep-gcc-11-x86_64-redhat-linux/bin/edep-sim:$PATH
run_command "Setting \$LD_LIBRAARY_PATH variable" export LD_LIBRARY_PATH=/exp/dune/app/users/wyjang/dune/edep-sim/edep-gcc-11-x86_64-redhat-linux/lib:$LD_LIBRARY_PATH
#run_command "Setting up jobsub_client" bash -c '. /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setup && setup jobsub_client && kx509 && voms-proxy-init -rfc -noregen -voms dune:/dune/Role=Analysis -valid 192:00'
set_prompt
