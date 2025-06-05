#!/bin/bash

source $HOME/.local/bin/utility.sh

echo "Setting Custom GENIE with BDM plugin ... "
run_command "GENIE=/exp/dune/app/users/wyjang/genie/3.02.04" export GENIE=/exp/dune/app/users/wyjang/genie/3.02.04
run_command "PATH=\$GENIE/bin:\$PATH" export PATH=$GENIE/bin:$PATH
run_command "LD_LIBRARY_PATH=\$GENIE/lib:\$LD_LIBRARY_PATH" export LD_LIBRARY_PATH=$GENIE/lib:$LD_LIBRARY_PATH
