#!/bin/sh
if [ ! -f $HOME/.local/bin/utility.sh ]; then
  printf "fnal_utility is not found."
  exit 1
else
  . $HOME/.local/bin/utility.sh
fi

if [ $(cat $HOME/.local/etc/dunegpvm) -lt 0 ]; then
  printf "[Error] Failed to capture the best dunegpvm node.\n"
  exit 1
fi

if [ $(cat $HOME/.local/etc/icarusgpvm) -lt 0 ]; then
  printf "[Error] Failed to capture the best icarusgpvm node.\n"
  exit 1
fi

duneidx=$(printf "%02d" "$(cat $HOME/.local/etc/dunegpvm)")
icarusidx=$(printf "%02d" "$(cat $HOME/.local/etc/icarusgpvm)")
gpvmhome_mntpt="$HOME/mnt/gpvm_home"
duneapp_mntpt="$HOME/mnt/dune_app"
dunedata_mntpt="$HOME/mnt/dune_data"
icarusapp_mntpt="$HOME/mnt/icarus_app"
icarusdata_mntpt="$HOME/mnt/icarus_data"
all_mntpt="$gpvmhome_mntpt $duneapp_mntpt $dunedata_mntpt $icarusapp_mntpt $icarusdata_mntpt"

detect_os() {
  case "$(uname -s)" in
    Darwin)
      printf "Darwin"
      ;;
    Linux)
      printf "Linux"
      ;;
    *)
      printf "Unsupported OS: $(uname -s)\n"
      exit 1
      ;;
  esac
}

sshfs_mount() {
  ostype=$(detect_os)
  mnt_option_name=""

  case "$ostype" in
    "Linux")
      mnt_option_name="x-gvfs-name"
      ;;
    "Darwin")
      mnt_option_name="volname"
      ;;
    *)
      printf "Unsupported OS\n"
      exit 1
      ;;
  esac

  sshfs "dunegpvm${duneidx}.fnal.gov:/nashome/w/${USER}/" $gpvmhome_mntpt -o "$mnt_option_name=gpvm-home"
  sshfs "dunegpvm${duneidx}.fnal.gov:/exp/dune/app/users/${USER}/" $duneapp_mntpt -o "$mnt_option_name=dunegpvm-app"
  sshfs "dunegpvm${duneidx}.fnal.gov:/exp/dune/data/users/${USER}/" $dunedata_mntpt -o "$mnt_option_name=dunegpvm-data"
  sshfs "icarusgpvm${icarusidx}.fnal.gov:/exp/icarus/app/users/${USER}/" $icarusapp_mntpt -o "$mnt_option_name=icarusgpvm-app"
  sshfs "icarusgpvm${icarusidx}.fnal.gov:/exp/icarus/data/users/${USER}/" $icarusdata_mntpt -o "$mnt_option_name=icarusgpvm-data"
}

sshfs_umount() {
  ostype=$(detect_os)
  umount_cmd=""
  case "$ostype" in
    "Linux")
      umount_cmd="fusermount -u"
      ;;
    "Darwin")
      umount_cmd="umount"
      ;;
    *)
      printf "unsupported os\n"
      exit 1
      ;;
  esac
  $umount_cmd "$gpvmhome_mntpt"
  $umount_cmd "$duneapp_mntpt"
  $umount_cmd "$dunedata_mntpt"
  $umount_cmd "$icarusapp_mntpt"
  $umount_cmd "$icarusdata_mntpt"

  echo 0
}

# ================== script entry point =====================

if [ "$1" = "-u" ] ; then
  run_command "Unmounting all gpvm sshfs points..." sshfs_umount
fi

if [ -z "$1" ] || [ "$1" = "-m" ] ; then
  run_command "Mounting gpvm sshfs points..." sshfs_mount
fi
