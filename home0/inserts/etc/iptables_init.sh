#! /bin/sh
# $Id: iptables_init.sh,v 1.10 2017/04/21 11:16:09 nanard Exp $
IPTABLES="`which iptables`" || exit 1
IPTABLES="$IPTABLES -w"
IP="`which ip`" || exit 1

EXTIF=INTERNET_INTERFACE
EXTIP="`LC_ALL=C $IP -4 addr show $EXTIF | awk '/inet/ { print $2 }' | cut -d "/" -f 1`"

mylogger "External IP = $EXTIP"

#adding the MINIUPNPD chain for nat
$IPTABLES -t nat -N MINIUPNPD
#adding the rule to MINIUPNPD
#$IPTABLES -t nat -A PREROUTING -d $EXTIP -i $EXTIF -j MINIUPNPD
$IPTABLES -t nat -A PREROUTING -i $EXTIF -j MINIUPNPD

#adding the MINIUPNPD chain for mangle
$IPTABLES -t mangle -N MINIUPNPD
$IPTABLES -t mangle -A PREROUTING -i $EXTIF -j MINIUPNPD

#adding the MINIUPNPD chain for filter
$IPTABLES -t filter -N MINIUPNPD
#adding the rule to MINIUPNPD
$IPTABLES -t filter -I FORWARD 1 -i $EXTIF ! -o $EXTIF -j MINIUPNPD

#adding the MINIUPNPD chain for nat
$IPTABLES -t nat -N MINIUPNPD-POSTROUTING
$IPTABLES -t nat -I POSTROUTING 1 -o $EXTIF -j MINIUPNPD-POSTROUTING
