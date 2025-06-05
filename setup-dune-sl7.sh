#!/bin/bash

echo "Running on SL7"
check_n_start_apptainer
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
export DUNELAR_VERSION=v10_03_01d00
export DUNELAR_QUALIFIER=e26:prof
run_command "Setting up dunesw $DUNELAR_VERSION $DUNELAR_QUALIFIER" setup dunesw $DUNELAR_VERSION -q $DUNELAR_QUALIFIER
echo "dunesw dir: $DUNESW_DIR"
export DUNE_PLOT_STYLE_VERSION=v01_01
run_command "Setting up dune_plot_style $DUNE_PLOT_STYLE_VERSION (null_qualifier)" setup dune_plot_style $DUNE_PLOT_STYLE_VERSION
kx509
export ROLE=Analysis
voms-proxy-init -rfc -noregen -voms=dune:/dune/Role=$ROLE -valid 120:00
setup ifdhc
export IFDH_TOKEN_ENABLE=0

