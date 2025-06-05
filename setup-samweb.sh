#!/bin/bash

function set_samweb() {
    if [ -z "$1" ]; then
      echo "ERROR: function set_samweb() require <experiment> argument. -- no argument provided."
      return 1
    fi
    exp=$1
    export SAM_EXPERIMENT=$exp 
    export SAM_GROUP=$exp
    export SAM_STATION=$exp 
    export SAM_WEB_HOST=sam$exp.fnal.gov 
    export IFDH_BASE_URI=http://sam$exp.fnal.gov:8480/sam/$exp/api/
    setup sam_web_client
}

function get_bearer_token() {
    if [ -z "$1" ]; then
      echo "ERROR: function get_bearer_token() require <experiment> argument. -- no argument provided."
      return 1
    fi
    exp=$1
    export BEARER_TOKEN_FILE=/tmp/bt_u$(id -u)
    htgettoken -a htvaultprod.fnal.gov -i $exp
}
