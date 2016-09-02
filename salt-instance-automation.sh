#!/bin/bash

# This bash script has 2 pseudo-functions related to automatically updating
# remote instances and removing instance snapshots
#
# os_apply_updates:
# This function uses salt to run OS updates on an Ubuntu or Windows
# instance. Only works on these two OSes, currently
# Example use..
# ./salt-instance-automation.sh os_apply_updates Fri ubuntuhost01
# ..this example will run the script and run OS updates on host
# ubuntuhost01 if the day of the week is Friday.
#
# remove_all_snapshots:
# This function uses salt-cloud to remove all snapshots for any given instance
# Example use..
# ./salt-instance-automation.sh remove_all_snapshots Fri ubuntuhost01
# ..this example will run the script and remove all snapshots from host
# ubuntuhost01 if the day of the week is Friday

# variable setup
TZ="America/New_York" # set the timezone
job=$1 # the job we wish to execute
dayofweek=$2 # day of the week
hostname=$3 # name of server being worked on
hostname_lc=$(echo "$hostname" | awk '{print tolower($0)}') # get lowercase format of hostname
working_dir=/srv/salt/scripts/
logfile=$working_dir/automation.log

echo $hostname_lc

# remove_all_snapshots
# this block of code removes all snapshots from a vm
if [ $job = remove_all_snapshots ] ; then

  # if it's the correct day of the week
  if [ $(date +"%a") = $dayofweek ] ; then
    echo " " >> $logfile
    echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - remove_all_snapshots $hostname_lc - start" >> $logfile
    echo " " >> $logfile
    salt-cloud -a remove_all_snapshots $hostname -y >> $logfile
    echo " " >> $logfile
    echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - remove_all_snapshots $hostname_lc - success" >> $logfile
    exit 0

  else # if wrong day of the week..
    echo " " >> $logfile
    echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - remove_all_snapshots $hostname_lc - aborted; wrong day" >> $logfile
    exit 0
  fi # end day of the week logic

fi # end remove_all_snapshots block


# os_apply_updates
# this block of code updates an instance

# if the job called = os_apply_updates
if [ $job = os_apply_updates ] ; then

  # if it's the correct day of the week
  if [ $(date +"%a") = $dayofweek ] ; then

    # if operating system is Ubuntu
    if salt ''$hostname_lc'' grains.item os>&1 | grep "Ubuntu"; then
      salt ''$hostname_lc'' pkg.refresh_db
      echo " " >> $logfile
      echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - os_apply_updates $hostname_lc - start" >> $logfile
      echo " " >> $logfile
      salt ''$hostname_lc'' pkg.upgrade dist_upgrade=False >> $logfile
      echo " " >> $logfile
      echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - os_apply_updates $hostname_lc - success" >> $logfile
      exit 0

    # end if operating system is Ubuntu logic

    # if operating system is Windows
    elif salt ''$hostname_lc'' grains.item os>&1 | grep "Windows"; then
      echo " " >> $logfile
      echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - os_apply_updates $hostname_lc - start" >> $logfile
      echo " " >> $logfile
      salt ''$hostname_lc'' win_wua.list_updates install=True >> $logfile
      salt ''$hostname_lc'' cmd.run "\"c:\Program Files\NSClient++\scripts\set_update_key.bat\""
      if salt ''$hostname_lc'' win_wua.get_needs_reboot>&1 | grep "True"; then
        echo " " >> $logfile
        salt ''$hostname_lc'' cmd.run "shutdown -r"
        echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - os_apply_updates $hostname_lc - reboot required" >> $logfile
      fi
      echo " " >> $logfile
      echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - os_apply_updates $hostname_lc - success" >> $logfile
      exit 0
      # end if operating system is Windows logic

    # if the operating system is NOT Ubuntu or Windows
    else
      echo " " >> $logfile
      echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - os_apply_updates $hostname_lc - only works with ubuntu or windows hosts" >> $logfile
      exit 0

    fi # end all operating system logic

  else # if wrong day of the week..
    echo " " >> $logfile
    echo "$(date +%Y-%m-%d) - $(date +%H:%M:%S%p) - remove_all_snapshots $hostname_lc - aborted; wrong day" >> $logfile
    exit 0

  fi # end day of the week logic

fi # end os_apply_updates block
