#!/bin/sh

echo "Running on SL7"
check_n_start_apptainer
. /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
CMAKE_VERSION=v3_27_4
run_command "Setting up cmake $CMAKE_VERSION" setup cmake $CMAKE_VERSION
export DUNELAR_VERSION=v10_08_00d00
export DUNELAR_QUALIFIER=e26:prof
run_command "Setting up dunesw $DUNELAR_VERSION $DUNELAR_QUALIFIER" setup dunesw $DUNELAR_VERSION -q $DUNELAR_QUALIFIER
echo "dunesw dir: $DUNESW_DIR"

export DUNE_PLOT_STYLE_VERSION=v01_01
run_command "Setting up dune_plot_style $DUNE_PLOT_STYLE_VERSION (null_qualifier)" setup dune_plot_style $DUNE_PLOT_STYLE_VERSION
get_bearer_token dune
#export ROLE=Analysis
#voms-proxy-init -rfc -noregen -voms=dune:/dune/Role=$ROLE -valid 120:00 -- deprecated, kx509 no longer being used
run_command "Setting up ifdc" setup ifdhc
export IFDH_TOKEN_ENABLE=0

