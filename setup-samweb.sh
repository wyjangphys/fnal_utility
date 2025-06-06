#!/bin/sh

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
    if [ "$ID" = "almalinux" ] && [ "${VERSION_ID#9}" != "$VERSION_ID" ] ; then
      spack load sam-web-client@3.4%gcc@12.2.0
    elif [ "$ID" = "scientific" ] && [ "${VERSION_ID#7}" != "$VERSION_ID" ] ; then
      setup sam_web_client
    else
      echo "Running on unknown Linux: $ID $VERSION_ID"
    fi
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
