#!/bin/sh

echo "Running on SL7"
check_n_start_apptainer
. /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
CMAKE_VERSION=v3_27_4
run_command "Setting up cmake $CMAKE_VERSION" setup cmake $CMAKE_VERSION
#export DUNELAR_VERSION=v10_08_00d00
#export DUNELAR_QUALIFIER=e26:prof
#run_command "Setting up dunesw $DUNELAR_VERSION $DUNELAR_QUALIFIER" setup dunesw $DUNELAR_VERSION -q $DUNELAR_QUALIFIER
echo "dunesw dir: $DUNESW_DIR"

run_command "Setting up dune_plot_style $DUNE_PLOT_STYLE_VERSION (null_qualifier)" setup dune_plot_style $DUNE_PLOT_STYLE_VERSION
run_command "Getting token for dune" get_bearer_token dune;export BEARER_TOKEN_FILE=/run/user/`id -u`/bt_u`id -u`
#run_command "Setting up ifdhc" setup ifdhc
#export IFDH_TOKEN_ENABLE=0

