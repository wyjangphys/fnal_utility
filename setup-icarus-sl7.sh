#!/bin/bash
source $HOME/.local/bin/utility.sh
source $HOME/.local/bin/setup-samweb.sh
set_prompt

alias ls='ls --color'
export appdir=/exp/icarus/app/users/wyjang
source /cvmfs/icarus.opensciencegrid.org/products/icarus/setup_icarus.sh
cd $appdir
echo -n "Working directory is: "
pwd

get_bearer_token icarus
set_samweb icarus
