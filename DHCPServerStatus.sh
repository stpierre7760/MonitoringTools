#!/bin/bash

#	Check OS X DHCP Status
#	modified by Jonathan Cohen
#	original script by Jedda Wignall
#	http://jedda.me

#	v1.1 - 21 Nov 2016
#	v1.0 - 7 Dec 2012 (Jedda)
#	Initial release.

#	Script that uses serveradmin to check that the OS X Server DHCP service is listed as running.
#	If all is OK, it checks that the number of active clients does not exceed a set threshold, then
#	returns performance data for the number of provided leases and number of active clients.

#	Required Arguments:
#	-w		Warning threshold for active clients. Script throws WARNING if number of active clients is greater than or equals the supplied number.
#	-c		Critical threshold for active clients. Script throws CRITICAL if number of active clients is greater than or equals the supplied number.
#	-t 		The target /24 subnet in the following notation "x.x.x" quotes are required.

#	Example:
#	./check_osx_swupdate.sh -w 120 -c 180

#	Performance Data - this script returns the followng Nagios performance data:
#	providedLeases -		Number of leases provided to clients (active & non-active).
#	activeClients -			Number of clients with an active lease.

#	Compatibility - this script has been tested on and functions on the following stock OSes:
#	10.6 Server
#	10.7 Server
#	10.8 Server
#	10.11.6 Server (Jonathan)


if [[ $EUID -ne 0 ]]; then
   printf "ERROR - This script must be run as root.\n"
   exit 1
fi

targetSubnet=""
warnThresh=""
critThresh=""

while getopts "w:c:t:" optionName; do
case "$optionName" in
w) warnThresh=( $OPTARG );;
c) critThresh=( $OPTARG );;
t) targetSubnet=( $OPTARG );;
esac
done

if [ "$warnThresh" == "" ]; then
	printf "ERROR - You must provide a warning threshold with -w!\n"
	exit 3
fi

if [ "$critThresh" == "" ]; then
	printf "ERROR - You must provide a critical threshold with -c!\n"
	exit 3
fi

# check that the dhcp service is running
dhcpStatus=`serveradmin fullstatus dhcp | grep 'dhcp:state' | sed -E 's/dhcp:state.+"(.+)"/\1/'`

if [ "$dhcpStatus" != "RUNNING" ]; then
	printf "CRITICAL - DHCP service is not running!\n"
	exit 2
fi

#Echo Target for Checking
#echo $targetSubnet

#This identifies the starting IP Address of the target DHCP scope.
startingAddress=`serveradmin settings dhcp | grep net_range_start | grep $targetSubnet | awk '{print substr($3, 10, length($3) - 10)}'`

#This identifies the last IP Address of the target DHCP scope.
endingAddress=`serveradmin settings dhcp | grep net_range_end | grep $targetSubnet | awk '{print substr($3, 10, length($3) - 10)}'`

#This determines the total number of addresses that is available in the target scope.
dhcpLeases=$(($endingAddress-$startingAddress))


#Now we need to identify active DHCP leases from the information provided in `serveradmin fullstatus dhcp`.  By default, serveradmin also returns information about expired leases, we need to clear this out of the results.
# grep -B will allow for the display of lines previous to the result and -A for after.
#First we exclude results that have negative time, then count the results that have positive time remaining.

dhcpActiveClients=`serveradmin fullstatus dhcp | grep -A 2 "$targetSubnet" | grep -v "timeLeft = -" | grep -B 2 "timeLeft = " | grep "$targetSubnet" | wc -l | awk {'print $1'}`


#Now we run our logic to determine if our DHCP status based on the original thresholds.
if [ "$dhcpActiveClients" -ge "$critThresh" ]; then
	printf "CRITICAL - $dhcpLeases leases ($dhcpActiveClients active clients) | providedLeases=$dhcpLeases; activeClients=$dhcpActiveClients;\n"
	exit 2
elif [ "$dhcpActiveClients" -ge "$warnThresh" ]; then
	printf "WARNING - $dhcpLeases leases ($dhcpActiveClients active clients) | providedLeases=$dhcpLeases; activeClients=$dhcpActiveClients; \n"
	exit 1
fi
	
printf "DHCP OK - $dhcpLeases leases ($dhcpActiveClients active clients) | providedLeases=$dhcpLeases; activeClients=$dhcpActiveClients;\n"
exit 0