#!/bin/bash
host=$(hostname)
experiment=$(echo "$host" | sed -E 's/^([a-z]+)gpvm[0-9]*\..*/\1/' | sed -E 's/build[0-9]*.*$//')

if [[ "$host" == *"build"* ]]; then
  pnfs_mount="/build"
else
  pnfs_mount="/pnfs/${experiment}"
fi

/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer shell --shell=/bin/bash \
-B /cvmfs,/exp,/nashome,$HOME,${pnfs_mount},/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf --ipc --pid \
/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest
