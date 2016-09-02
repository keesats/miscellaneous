#!/bin/bash
# Merges the config written from asa-lists-01-create-lists.sh to
# the running configuration on the ASA in question

# Variables
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH
TFTPSERV="1.1.1.1"
FWIP="1.1.1.2"
FWUSERNAME=$(head -n 1 /root/asa_creds)
PASSWORD=$(tail -1 /root/asa_creds)
ENPASSWORD=""
FWHOSTNAME="ASA-HOSTNAME"
SORTEDLIST="sorted-list.txt"

# Make sure expect is installed.
EXP="$(which expect)"

if [ $? -ne 0 ] ; then
  echo "Expect binary not found, exiting"
  exit 1
elif [ -e "$EXP" ] ; then
  echo "Expect binary found, running"
fi

# Log in to the ASA and merge the contents of the file
# into the running configuration
$EXP - << EndMark
spawn ssh -l $FWUSERNAME $FWIP

expect "*assword:"
  exp_send -- "$PASSWORD\r"
expect "$FWHOSTNAME>"
  exp_send -- "enable\r"
expect "*assword:"
  exp_send -- "$ENPASSWORD\r"
expect "$FWHOSTNAME#"
  exp_send -- "
  copy /noconfirm tftp://$TFTPSERV/$SORTEDLIST running-config\r"
expect "$FWHOSTNAME#"
  exp_send -- "exit\r"
interact
EndMark

# Exit
exit 0
