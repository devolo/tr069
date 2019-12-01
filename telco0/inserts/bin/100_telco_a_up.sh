#!/bin/sh

ACS_IP=$(try_up_to_n_times "dig +noall +answer +search acs | awk '{ print \$5 }'")
GENIEACS_IP=$(try_up_to_n_times "dig +noall +answer +search genieacs | awk '{ print \$5 }'")

# Redirect 7547, 7557, 7567 and 7070 to GenieACS
redirect 7547 tcp ${INTERNET_INTERFACE} ${GENIEACS_IP} 7547
redirect 7557 tcp ${INTERNET_INTERFACE} ${GENIEACS_IP} 7557
redirect 7567 tcp ${INTERNET_INTERFACE} ${GENIEACS_IP} 7567
redirect 7070 tcp ${INTERNET_INTERFACE} ${GENIEACS_IP} 7070

PROXY_IP=$(try_up_to_n_times "dig +noall +answer +search nginx | awk '{ print \$5 }'")
# Redirect HTTP (tcp/80) to the proxy server (nginx) -> web HTTP
redirect 80 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 80
# Redirect HTTPS (tcp/443) to the proxy server (nginx) -> web HTTPS
redirect 443 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 443
# Redirect (tcp/9000) to the proxy server (nginx) -> OpenACS HTTP
redirect 9000 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 9000
# Redirect (tcp/9001) to the proxy server (nginx) -> OpenACS with client cert and HTTPS
redirect 9001 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 9001
# Redirect (tcp/9001) to the proxy server (nginx) -> OpenACS without client cert and HTTPS
redirect 9002 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 9002
# Redirect (tcp/9010) to the proxy server (nginx) -> OpenACS HTTP basic auth
redirect 9010 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 9010
# Redirect (tcp/9011) to the proxy server (nginx) -> OpenACS HTTP digest auth
redirect 9011 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 9011
# Redirect (tcp/10000) to the proxy server (nginx) -> GenieACS HTTP basic auth
redirect 10000 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 10000
# Redirect (tcp/10001) to the proxy server (nginx) -> GenieACS HTTP digest auth
redirect 10001 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 10001
# Redirect (tcp/10002) to the proxy server (nginx) -> GenieACS with client cert and HTTPS
redirect 10002 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 10002
# Redirect (tcp/10003) to the proxy server (nginx) -> GenieACS with client cert and HTTPS basic auth
redirect 10003 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 10003
# Redirect (tcp/10002) to the proxy server (nginx) -> GenieACS without client cert and HTTPS
redirect 10004 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 10004
# Redirect (tcp/10003) to the proxy server (nginx) -> GenieACS without client cert and HTTPS basic auth
redirect 10005 tcp ${INTERNET_INTERFACE} ${PROXY_IP} 10005
# allow ntp on PROXY_IP
iptables -A INPUT -i ${LOCAL_INTERFACE} -p udp --sport 123 -j ACCEPT
iptables -A FORWARD -i ${LOCAL_INTERFACE} -p udp --sport 123 -j ACCEPT

STUN_IP=$(try_up_to_n_times "dig +noall +answer +search stun | awk '{ print \$5 }'")

tweak_firewall_for_stun()
{
    local UDP_STUN_PORT=${1}

    redirect ${UDP_STUN_PORT} udp ${INTERNET_INTERFACE} ${STUN_IP} ${UDP_STUN_PORT}

    iptables -A INPUT -i ${LOCAL_INTERFACE} -p udp --sport ${UDP_STUN_PORT} -j ACCEPT
    iptables -A FORWARD -i ${LOCAL_INTERFACE} -p udp --sport ${UDP_STUN_PORT} -j ACCEPT

    while true; do sleep 1; conntrack -L 2>/dev/null | grep ${UDP_STUN_PORT} | sed 's/=/ /g' | awk '{ system ("conntrack -D -s "$5" -d "$7" -p "$1" --sport="$9" --dport="$11) }'; done &
}

# Redirect stun ports to the stun server
tweak_firewall_for_stun 3478
# Redirect alternative stun ports to the stun server
tweak_firewall_for_stun 3479

# Allow forwarding from local interface to external interface, so e.g. the HTTP connection request will work
iptables -A FORWARD -i ${LOCAL_INTERFACE} -o ${INTERNET_INTERFACE} -j ACCEPT

mylogger "${HOSTNAME} up"
