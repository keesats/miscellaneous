#!/bin/bash
#
# This job downloads various IP lists and
# re-writes them into a file that can be
# merged into a running Cisco ASA config
# to be used as a dynamic-filter for blocking
# inbound/outbound traffic.

# global variables
ASANAMEONE="ASA-ONE-HOSTNAME"
BASEPATH="/srv/salt/scripts/"
BASETFTP="/tftpboot/"
DATESTAMP=$(/bin/date +%Y.%m.%d.at.%H.%M.%S)
FWENPASSWORD=""
FWPASSWORD=$(tail -1 /root/asa_creds)
FWUSERNAME=$(head -n 1 /root/asa_creds)
LISTCOMPROMISED="list-compromised.txt"
LISTPIX="list-pix.txt"
LISTRANSOM="list-ransomeware.txt"
LISTTEMP="list-temp.txt"
LISTZEUS="list-zeus-tracker.txt"
SORTEDLIST="sorted-list.txt"

# path setup
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

# delete old downloaded lists
rm $BASEPATH/$LISTCOMPROMISED
rm $BASEPATH/$LISTPIX
rm $BASEPATH/$LISTRANSOM
rm $BASEPATH/$LISTZEUS

# grab & rewrite current lists
# ET Compromised IPs
wget https://rules.emergingthreats.net/blockrules/compromised-ips.txt -O $BASEPATH/$LISTTEMP
sed -e 's/^/address /' -e 's/$/ 255.255.255.255/' \
  $BASEPATH/$LISTTEMP >> $BASEPATH/$LISTCOMPROMISED

# ET PIX Firewall Rules
wget https://rules.emergingthreats.net/fwrules/emerging-PIX-ALL.rules -O $BASEPATH/$LISTTEMP
sed 's/ET-all/ET-cc/g' $BASEPATH/$LISTTEMP | egrep "^access-list ET-cc deny" \
  | sed 's/access-list ET-cc deny ip/address/g;s/host //g;s/any/255.255.255.255/g' | \
    awk '{print $1,$2,$3}' > $BASEPATH/$LISTPIX

# RansomewareTracker IPs
wget http://ransomwaretracker.abuse.ch/downloads/RW_IPBL.txt -O $BASEPATH/$LISTTEMP
sed -e '/^#/ d;/^$/d' -e 's/^/address /' -e 's/$/ 255.255.255.255/' \
  $BASEPATH/$LISTTEMP > $BASEPATH/$LISTRANSOM

# ZeusTracker IPs
wget https://zeustracker.abuse.ch/blocklist.php?download=badips -O $BASEPATH/$LISTTEMP
sed -e '/^#/ d;/^$/d' -e 's/^/address /' -e 's/$/ 255.255.255.255/' \
  $BASEPATH/$LISTTEMP > $BASEPATH/$LISTZEUS

# Remove temp file
rm $BASEPATH/$LISTTEMP

# Delete old files
rm $BASEPATH/$SORTEDLIST
rm $BASETFTP/$SORTEDLIST

# Combine lists wanted for use
cat $BASEPATH/$LISTCOMPROMISED > $BASEPATH/$LISTTEMP
cat $BASEPATH/$LISTPIX >> $BASEPATH/$LISTTEMP
cat $BASEPATH/$LISTRANSOM >> $BASEPATH/$LISTTEMP
cat $BASEPATH/$LISTZEUS >> $BASEPATH/$LISTTEMP

# Create final sorted listed for that will clear
# the existing dynamic-filter and add all IPs from lists that
# were chosen, in numerical order
echo "no dynamic-filter blacklist" > $BASEPATH/$SORTEDLIST
echo "dynamic-filter blacklist" >> $BASEPATH/$SORTEDLIST
sort -d -r $BASEPATH/$LISTTEMP >> $BASEPATH/$SORTEDLIST

# Transfer file to TFTP root dir and set permissions
cp $BASEPATH/$SORTEDLISTONE $BASETFTP
chmod 775 $BASETFTP/$SORTEDLIST
chown nobody $BASETFTP/$SORTEDLIST

# Exit
exit 0
