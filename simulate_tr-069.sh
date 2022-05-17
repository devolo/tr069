#!/bin/sh

# halt on errors, please
set -e
#set -x

DEFAULT_IMAGE_VERSION="1.3.8"
SCRIPT_VERISON="1.3.9"

################################################################################
#
# functions for variable handling
#
################################################################################

get_address_prefix () {
    ADDRESS=${1}
    NUMBER_OF_BITS=$(echo "${ADDRESS}" | awk -F/ '{ print $2 }')
    IP=$(echo "${ADDRESS}" | awk -F/ '{ print $1 }')
    case ${NUMBER_OF_BITS} in
	8)
	    echo "${IP}" | awk -F. '{ print $1 }'
	    ;;
	16)
	    echo "${IP}" | awk -F. '{ print $1"."$2 }'
	    ;;
	20) # evil, hopefully not too evil
	    echo "${IP}" | awk -F. '{ print $1"."$2"."$3 }'
	    ;;
	24)
	    echo "${IP}" | awk -F. '{ print $1"."$2"."$3 }'
	    ;;
	32)
	    echo "${IP}" | awk -F. '{ print $1"."$2"."$3"."$4 }'
	    ;;
	*)
	    echo "get_address_prefix is not prepared for such advanced address handling ..." > /dev/stderr
	    exit 1
	    ;;
    esac
}

# backwards compatibility ...
if [ "${MY_PHYSICAL_INTERFACE}" != "" ]; then
    MY_DUT_INTERFACE="${MY_PHYSICAL_INTERFACE}"
fi

################################################################################
#
# environment variables to follow
#
################################################################################
NBS_PROJECT=${NBS_PROJECT:-tr069}
NBS_ADDON=${NBS_ADDON:-""}
VERSION=${VERSION:-$DEFAULT_IMAGE_VERSION}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYHTTP_PORT=${MYHTTP_PORT:-8080}
ADDITIONAL_NAMESERVER=${ADDITIONAL_NAMESERVER:-\"\"}
MY_DUT_INTERFACE=${MY_DUT_INTERFACE:-enp5s0.66}
MY_HELPER_INTERFACE=${MY_HELPER_INTERFACE:-sim-${NBS_PROJECT}-net}
MY_HELPER_INTERFACE_IP=${MY_HELPER_INTERFACE_IP:-"DHCP"}
MY_UPSTREAM_INTERFACE=${MY_UPSTREAM_INTERFACE:-enp5s0.25}
MY_UPSTREAM_INTERFACE_ACCEPTS_DEFAULT_GW=${MY_UPSTREAM_INTERFACE_ACCEPTS_DEFAULT_GW:-"NO"}
MY_UPSTREAM_NETWORK_SHALL_BE_REACHABLE_THROUGH_THE_SIMULATED_NETWORK=${MY_UPSTREAM_NETWORK_SHALL_BE_REACHABLE_THROUGH_THE_SIMULATED_NETWORK:-"NO"}
PATCH_MY_RESOLVE_CONF=${PATCH_MY_RESOLVE_CONF:-"NO"}
PATCH_MY_DHCP_SERVER_FOR_OPTION_125_WORKAROUND=${PATCH_MY_DHCP_SERVER_FOR_OPTION_125_WORKAROUND:-"NO"}
PATCH_MY_DHCP_SERVER_FOR_OPTION_43_WORKAROUND=${PATCH_MY_DHCP_SERVER_FOR_OPTION_43_WORKAROUND:-"NO"}
PATCH_MY_HOSTS=${PATCH_MY_HOSTS:-"no"}
ACS_URL_TO_USE_OPTION125=${ACS_URL_TO_USE_OPTION125:-http://telco0.public:7547}
ACS_URL_TO_USE_OPTION43=${ACS_URL_TO_USE_OPTION43:-http://telco0.public:9000/openacs/acs}
PROVISIONING_CODE=${PROVISIONING_CODE:-code12345}
WAIT_INTERVAL=${WAIT_INTERVAL:-86400}
WAIT_INTERVAL_MULTIPLIER=${WAIT_INTERVAL_MULTIPLIER:-1}
USE_OPTION_125_MODE=${USE_OPTION_125_MODE:-BBF}
USE_OPTION_43_MODE=${USE_OPTION_43_MODE:-BBF}

export MYSQL_PORT
export MYHTTP_PORT
export MY_DUT_INTERFACE
export MY_UPSTREAM_INTERFACE
export PATCH_MY_DHCP_SERVER_FOR_OPTION_125_WORKAROUND
export PATCH_MY_DHCP_SERVER_FOR_OPTION_43_WORKAROUND
export VERSION
export ACS_URL_TO_USE_OPTION125
export ACS_URL_TO_USE_OPTION43
export PROVISIONING_CODE
export WAIT_INTERVAL
export WAIT_INTERVAL_MULTIPLIER
export USE_OPTION_125_MODE
export USE_OPTION_43_MODE
export NBS_PROJECT

COMMAND=${1:-"help"}
NBS_NETWORKS_TO_SNIFF=${NBS_NETWORKS_TO_SNIFF:-""}

RESOLV_FILE=/etc/resolv.conf
HOSTS_FILE=/etc/hosts

WIRESHARK_HOSTS_FILE=~/.config/wireshark/hosts

START_PATTERN="####${NBS_PROJECT}START####"
END_PATTERN="###${NBS_PROJECT}END###"

HOSTS_TO_TEST=""

################################################################################
#
# help / usage / fm / README.md
#
################################################################################

display_help_to () {
    FILE=${1:-/dev/stdout}
    display_message "README.md"
    cat README.md > "${FILE}"
    display_message "help"
    cat <<EOF  > "${FILE}"
This is ${0}, v${SCRIPT_VERSION} (default image v${CURRENT_VERISON})
  used to create, configure and examine a virtual TR-069 test network. Unfortunately you need superuser rights to use this.

Usage: sudo -E sh simulate_tr-069.sh [build|up|down|remove|purge_network|purge|test_setup|wireshark|help|test]

 Commands:
    * build         : pulls Ubuntu 18.04 and 12.04, builds all images, tags them and executes 'up'
    * up            : starts all containers, tags them if not yet done, adds the local helper interface for HOST connection, waits for all ACSes to start and executes some basic networking tests
    * down          : removes the helper interface for HOST connection and stops all containers
    * remove        : executes 'down' and removes all ${NBS_PROJECT} images of current version and latest
    * purge_network : stopping docker daemon, removing all networks and restarting the daemon again; use with care
    * purge         : executes 'down' and removes all ${NBS_PROJECT} images
    * test_setup    : executes 'remove', 'build' and 'up'
    * wireshark     : starts wireshark to sniff the given network; if no network name given, displays available network names
    * list          : list network names
    * help          : displays this text
    * test          : executes some basic networking tests
EOF
}

################################################################################
#
# functions
#
################################################################################

display_message() {
    echo
    echo "*******************************************************************"
    echo "* ${*}"
    echo "*******************************************************************"
    echo
}

version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# to find a free subnet
find_addresses_for() {
    NETWORK=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    eval ALREADY_SET=\${${NETWORK}_IP_ADDRES_BYTE}
    if [ -z "${ALREADY_SET}" ]; then
	ADDRESS_USED="-"
	for SUBNET in $(seq 0 250); do
	    ADDRESS_USED=$(ip addr show | grep "192\\.168\\.${SUBNET}\\.") || true
	    if [ -z "${ADDRESS_USED}" ]; then
		ADDRESS_USED=$(export | grep IP_ADDRES_BYTE | grep "${SUBNET}") || true
		if [ -z "${ADDRESS_USED}" ]; then
		    echo "Using 192.168.${SUBNET}.0/24 for $1 ..."
		    export ${NETWORK}_IP_ADDRES_BYTE="${SUBNET}"
		    break;
		fi
	    fi
	done
	if [ ! -z "${ADDRESS_USED}" ]; then
	    echo "Can not use $1, no free subnet, aborting ..."
	    exit 2
	fi
    else
	echo "Using already set 192.168.${ALREADY_SET}.0/24 for $1 ..."
    fi
}

# to connect the host system to the simulated world ... the host uses the fixed last byte of 200
# at its IP address; the gateway only serves IPs from 100 to 199, which should be ok.
add_helper_interface(){
    if [ ! -d "/sys/class/net/${MY_HELPER_INTERFACE}" ]; then
	sudo ip link add "${MY_HELPER_INTERFACE}" link "${MY_DUT_INTERFACE}" type macvlan  mode bridge
	sudo ip link set "${MY_HELPER_INTERFACE}" up
	if [ "${MY_HELPER_INTERFACE_IP}" = "DHCP" ]; then
	    sudo dhclient -v -4 -i "${MY_HELPER_INTERFACE}" || ( display_message "DHCP with dhclient failed, think about using \"export MY_HELPER_INTERFACE_IP=192.168.${HOME0_IP_ADDRES_BYTE}.250/24\" ..." && exit 1)
	else
	    sudo ip addr add "${MY_HELPER_INTERFACE_IP}" dev "${MY_HELPER_INTERFACE}" || ( display_message "IP setup failed, think about using \"export MY_HELPER_INTERFACE_IP=192.168.${HOME0_IP_ADDRES_BYTE}.250/24\" ..." && exit 1)
	    export PATCH_MY_RESOLVE_CONF="YES"
	fi
	NEW_GW_NAMESERVER=$(docker exec ${NBS_PROJECT}_home0 ip addr show | grep "192.168.${HOME0_IP_ADDRES_BYTE}"  | awk -F/ '{ print $1 }' | awk '{ print $2 }')
	if [ "${MY_UPSTREAM_INTERFACE_ACCEPTS_DEFAULT_GW}" = "NO" ]; then
	    sudo sh poll_default_gateway.sh "${NEW_GW_NAMESERVER}" &
	fi
	sudo ip route add "192.168.${UPSTREAM_IP_ADDRES_BYTE}.0/24" via "${NEW_GW_NAMESERVER}" dev "${MY_HELPER_INTERFACE}"
	IS_NETWORK_MANAGER_NOT_INSTALLED=$(dpkg -s network-manager 2>&1 | grep "not installed") || true
	if [ "${IS_NETWORK_MANAGER_NOT_INSTALLED}" != "" ] || [ "${PATCH_MY_RESOLVE_CONF}" = "YES" ]; then
	    # the network-manager is not installed, so the nameserver of the simulation is not added
	    # automatically and therefore must be added to the HOST system by patching resolv.conf
	    rm -f /tmp/myresolv.conf
	    {
		echo "${START_PATTERN}"
		echo "nameserver ${NEW_GW_NAMESERVER}"
		echo "${END_PATTERN}"
		cat "${RESOLV_FILE}"
	    } >> /tmp/myresolv.conf
	    sudo mv /tmp/myresolv.conf "${RESOLV_FILE}"
	fi
	if [ "${MY_UPSTREAM_NETWORK_SHALL_BE_REACHABLE_THROUGH_THE_SIMULATED_NETWORK}" != "NO" ]; then
	    UPSTREAM_NETWORK=$(docker exec ${NBS_PROJECT}_upstream ip route show | grep src | awk '{ print $1 }')
	    sudo ip route add "${UPSTREAM_NETWORK}" via "${NEW_GW_NAMESERVER}"
	fi
	# make SSDP to be routed into the local TR-069 network, so that the home0 gateway will be seen for TR-064
	sudo ip route add "239.0.0.0/8" dev "${MY_HELPER_INTERFACE}"
    fi
}

remove_helper_interface(){
    if [ -d "/sys/class/net/${MY_HELPER_INTERFACE}" ]; then
	sudo ip link set "${MY_HELPER_INTERFACE}" down
	sudo ip link del "${MY_HELPER_INTERFACE}"
	pgrep -f "dhclient.*${MY_HELPER_INTERFACE}" | xargs sudo kill 2>/dev/null || true
	sudo killall poll_default_gateway.sh 2>/dev/null || true
    fi
    pgrep -f rename_wireshark_window | xargs sudo kill 2>/dev/null || true
}

# to throw away the added hosts easily, insert them between the start and end pattern
# this is not atomic and may fail if some changes to WIRESHARK_HOSTS_FILE are done by the
# system during populate_hosts ...
populate_hosts() {
    CONTAINERS=$(docker ps --format '{{.Names}}'| grep ${NBS_PROJECT}_ )

    mkdir -p "$(dirname ${WIRESHARK_HOSTS_FILE})"
    echo ${START_PATTERN}>>${WIRESHARK_HOSTS_FILE}
    for CONTAINER in ${CONTAINERS}; do
	HOSTS=$(docker exec "${CONTAINER}" sh -c "cat /etc/hosts" 2>/dev/null) || true
	WIRESHARK_DATA=$(echo "${HOSTS}" | grep -v localhost | grep -v ::) || true
	echo "${WIRESHARK_DATA}">>${WIRESHARK_HOSTS_FILE}
    done
    echo ${END_PATTERN}>>${WIRESHARK_HOSTS_FILE}
}

generate_list_of_hosts_to_test() {
    HOSTS_TO_TEST="$(
    for FILE in ${NBS_PROJECT} ${NBS_ADDON}; do
	cat ${FILE}.nbs | grep "#nbs resolve" | while read COMMAND
	do
	    HOSTS_TO_TEST="$(echo ${COMMAND} | awk -F';' '{ print $2 }')"
	    echo "${HOSTS_TO_TEST}"
	done
    done)"
}

# upstream ist the source for public IP addresses
patch_hosts() {
    generate_list_of_hosts_to_test
    echo ${START_PATTERN}>>${HOSTS_FILE}
    for HOST in ${HOSTS_TO_TEST}; do
	HOST_OUTPUT=$(docker exec ${NBS_PROJECT}_upstream host ${HOST})
	IP=$(echo ${HOST_OUTPUT} | awk '{ print $4 }')
	FQDN=$(echo ${HOST_OUTPUT} | awk '{ print $1 }')
	sudo echo ${IP} ${FQDN} ${HOST} >> ${HOSTS_FILE}
    done
    echo ${END_PATTERN}>>${HOSTS_FILE}
 }

remove_hostfs_changes() {
    # || true is meant to not fail if e.g. the files are not present
    [ -f ${WIRESHARK_HOSTS_FILE} ] && sed -i "/${START_PATTERN}/,/${END_PATTERN}/d" ${WIRESHARK_HOSTS_FILE} || true
    [ -f ${RESOLV_FILE} ] && sudo sed -i "/${START_PATTERN}/,/${END_PATTERN}/d" ${RESOLV_FILE} || true
    [ -f ${HOSTS_FILE} ] && sed -i "/${START_PATTERN}/,/${END_PATTERN}/d" ${HOSTS_FILE} || true
}

# some checks to help the system be usable
check_interface() {
    INTERFACE=${1%.*}
    INTERFACE_STATE=$(cat "/sys/class/net/${INTERFACE}/operstate")
    USED_MAC_ADDRESS=$(cat "/sys/class/net/${INTERFACE}/address")
    # simply check that the interface is actually installed
    if [ ! -d "/sys/class/net/${INTERFACE}" ]; then
	echo "There is no interface ${INTERFACE}!" > /dev/stderr
	echo > /dev/stderr
	echo "Please check ${1} and set it correctly with e.g. 'export ${2}=eth0.${3}'!" > /dev/stderr
	exit 2
    fi
    # if the name is longer than 15 characters, an error will be thrown by docker at
    # setting up the VLAN.
    if [ "$(echo "${1}" | wc  -c)" -gt 15 ]; then
	echo "The string \"${INTERFACE}\" is too long, are you using an USB network interface and systemd?" > /dev/stderr
	echo > /dev/stderr
	echo "Please shorten the length by e.g. storing \'ACTION==\"add\", SUBSYSTEM==\"net\",ATTR{address}==\"${USED_MAC_ADDRESS}\",ATTR{dev_id}==\"0x0\",NAME=\"usb\"\' in the file '/etc/udev/rules.d/10-usb.rules'." > /dev/stderr
	echo > /dev/stderr
	echo "Then please uplug the USB network interface and plug it in again." > /dev/stderr
	exit 2
    fi
    # if there is no link at the interface to test, the packet flow will not work
    # as expected. E.G. you can not reach the simulated servers from your host, the
    # simulation will simply work only internally.
    if [ "${INTERFACE_STATE}" = "down" ]; then
	echo "Connect at least a DUT to ${INTERFACE}, there is no link!" > /dev/stderr
	echo > /dev/stderr
	echo "Please unplug the cable at ${INTERFACE}, then count to three, no more, no less." > /dev/stderr
	echo "Three shall be the number thou shalt count, and the number of the counting shall be three." > /dev/stderr
	echo "Four shalt thou not count, neither count thou two, excepting that thou then proceed to three." > /dev/stderr
	echo "Five is right out." > /dev/stderr
	echo "Once the number three, being the third number, be reached, then plug in the cable again." > /dev/stderr
	echo > /dev/stderr
	echo "If this happens again, think about the other end of the cable." > /dev/stderr
	exit 2
    fi
}

# make sure that docker-compose is installed
check_tools() {
    if [ -z $(which docker-compose) ]; then
        display_message "Neccessary tool docker-compose is not installed, aborting ..."
	exit 3
    fi
}

# poll the log and wait for the magic string ...
check_log_periodically_until() {
    SERVICE_NAME="${1}"
    STRING_TO_CHECK="${2}"
    display_message "Waiting for ${SERVICE_NAME} to start ..."
    for TRY in $(seq 1 140); do
	echo "${TRY}"
	ACS_STARTED_UP=$(docker logs ${NBS_PROJECT}_${SERVICE_NAME} | grep "${STRING_TO_CHECK}") || true
	if [ ! -z "${ACS_STARTED_UP}" ]; then
	    echo "${SERVICE_NAME} is up and running!"
	    break;
	else
	    sleep 1
	fi
    done
    if [ -z "${ACS_STARTED_UP}" ]; then
	display_message "Sorry, no ${SERVICE_NAME} ..."
	exit 3
    fi
}

execute_nbs_command() {
    for FILE in ${NBS_PROJECT} ${NBS_ADDON}; do
	cat ${FILE}.nbs | grep "#nbs ${1}" | while read COMMAND
	do
	    ARG1="$(echo ${COMMAND} | awk -F';' '{ print $2 }')"
	    ARG2="$(echo ${COMMAND} | awk -F';' '{ print $3 }')"
	    ${2} "${ARG1}" "${ARG2}"
	done
    done
}

wait_for_container_to_start() {
    execute_nbs_command "wait" check_log_periodically_until
}

# errors were seen due to an old ubuntu:18.04 image ... pull it to be up to date
docker_pull() {
    docker pull ubuntu:18.04
    docker pull ubuntu:12.04
    echo ""
}

test_download_from_url() {
    display_message "Testing download of URL ${2} from ${1} ..."
    wget -O "out.html" "${2}" || if [ "$?" != "3" ]; then exit 1; else echo "File I/O error ignored..."; fi
    rm "out.html"
}

ping_once() {
    display_message "Pinging ${1} ..."
    ping -c 1 ${1}.public
}
test_networking() {
    execute_nbs_command "resolve" ping_once
    execute_nbs_command "url" test_download_from_url

    NMAP_AVAILABLE=$(which nmap) || true
    if [ ! -z "${NMAP_AVAILABLE}" ]; then
	display_message "Testing STUN  port of telco0 ..."
	RESULT=$(nmap -sU -p 3478 telco0.public | grep open) || true
	if [ -z "${RESULT}" ]; then
	    display_message "Sorry, no STUN port ..."
	    exit 4
	fi
    else
	display_message "Sorry, no nmap, no port testing ..."
    fi
}

set_correct_wireshark_window_name() {
    INTERFACE_TO_SNIFF=${1}
    NETWORK=${2}
    ./rename_wireshark_window.sh "${INTERFACE_TO_SNIFF}"  "${NETWORK}" &
}

get_interface_to_sniff() {
    NETWORK=${1}
    NETWORK_TO_SNIFF=$(docker network ls | grep "${NETWORK}" | awk '{ print $1 }')
    if [ ! -z "${NETWORK_TO_SNIFF}" ]; then
	INTERFACE_TO_SNIFF=$(docker network inspect --format '{{ .Options.parent }}' "${NETWORK_TO_SNIFF}")
	if [ "${INTERFACE_TO_SNIFF}" = "<no value>" ]; then
	    INTERFACE_TO_SNIFF="dm-${NETWORK_TO_SNIFF}"
	fi
    fi
    echo "${INTERFACE_TO_SNIFF}"
}

NETWORK_ITEM_GLUE="-"
list_networks() {
    NETWORK_LIST=$(docker network ls | grep ${NBS_PROJECT}_ | awk -v _=${NETWORK_ITEM_GLUE} '{ print $1_$2 }')
    for NETWORK_ITEM in ${NETWORK_LIST}; do
	NETWORK=$(echo ${NETWORK_ITEM} | awk -F"${NETWORK_ITEM_GLUE}" '{ print $1 }')
	NETWORK_NAME=$(echo ${NETWORK_ITEM} | awk -F"${NETWORK_ITEM_GLUE}" '{ print $2 }')
	INTERFACE_NAME=$(docker network inspect --format '{{ .Options.parent }}' "${NETWORK}")
	if [ "${INTERFACE_NAME}" = "<no value>" ]; then
	    INTERFACE_NAME="dm-${NETWORK}"
	fi
	echo "${NETWORK_NAME}\t${NETWORK}\t${INTERFACE_NAME}"
    done
}

# to sniff the traffic in the correct docker network
start_wireshark () {
    NETWORK=${1}
    WIRESHARK_AVAILABLE=$(which wireshark) || true
    if [ ! -z "${WIRESHARK_AVAILABLE}" ]; then
	INTERFACE_TO_SNIFF=$(get_interface_to_sniff "${NETWORK}")
	if [ ! -z "${INTERFACE_TO_SNIFF}" ]; then
	    wireshark -N mnNd -i "${INTERFACE_TO_SNIFF}" -k 1>/dev/null 2>/dev/null &
	    XDOTOOL_AVAILABLE=$(which xdotool) || true
	    if [ ! -z "${XDOTOOL_AVAILABLE}" ]; then
		set_correct_wireshark_window_name "${INTERFACE_TO_SNIFF}" "${NETWORK}"
	    else
		if [ ! -f /tmp/no_xdotool_wished ]; then
		    while true; do
			display_message "Do you wish to install \"xdotool\" to set the network name for the wireshark window? (y/n)"
			read -r yn
			case $yn in
			    [Yy]* ) apt-get install xdotool; set_correct_wireshark_window_name "${INTERFACE_TO_SNIFF}" "${NETWORK}"; break;;
			    [Nn]* ) touch /tmp/no_xdotool_wished; break;;
			    * ) echo "Please answer yes or no!";;
			esac
		    done
		else
		    display_message "You did not install \"xdotool\" to set the network name for the wireshark window. Remove /tmp/no_xdotool_wished to choose again ..."
		fi
	    fi
	else
	    display_message "Sorry, no network ${NETWORK} found ..."
	fi
    else
	display_message "Sorry, no wireshark, no sniffing ..."
    fi
}

check_apparmor_tools () {
    IS_GENPROF_INSTALLED=$(which aa-genprof) || true
    IS_NOTIFY_INSTALLED=$(which aa-notify) || true
    if [ -z "${IS_GENPROF_INSTALLED}" ] || [ -z "${IS_NOTIFY_INSTALLED}" ]; then
	while true; do
	    display_message "Do you wish to install \"aa-genprof\" and \"aa-notify\" to generate and check an apparmor profile for this simulation? (y/n)"
	    read -r yn
	    case $yn in
		[Yy]* )
		    sudo apt-get install apparmor-utils
		    sudo adduser "$USER" adm
		    sudo apt install apparmor-notify
		    break
		    ;;
		[Nn]* )
		    touch /tmp/no_aa_tools_wished
		    exit 1
		    ;;
		* ) echo "Please answer yes or no!";;
	    esac
	done
    fi
}

display_settings () {
    display_message "NBS settings of v${SCRIPT_VERISON} (default image v${DEFAULT_IMAGE_VERSION}):"
    echo " VERSION=${VERSION} ; image version to use"
    echo " NBS_PROJECT=${NBS_PROJECT} ; project to use"
    echo " NBS_ADDON=${NBS_ADDON} ; addons to use"
    echo " ADDITIONAL_NAMESERVER=${ADDITIONAL_NAMESERVER}"
    echo " MY_DUT_INTERFACE=${MY_DUT_INTERFACE}"
    echo " MY_HELPER_INTERFACE=${MY_HELPER_INTERFACE}"
    echo " MY_HELPER_INTERFACE_IP=${MY_HELPER_INTERFACE_IP}"
    echo " MY_UPSTREAM_INTERFACE=${MY_UPSTREAM_INTERFACE}"
    echo " MY_UPSTREAM_INTERFACE_ACCEPTS_DEFAULT_GW=${MY_UPSTREAM_INTERFACE_ACCEPTS_DEFAULT_GW}"
    echo " MY_UPSTREAM_NETWORK_SHALL_BE_REACHABLE_THROUGH_THE_SIMULATED_NETWORK=${MY_UPSTREAM_NETWORK_SHALL_BE_REACHABLE_THROUGH_THE_SIMULATED_NETWORK}"
    echo " PATCH_MY_RESOLVE_CONF=${PATCH_MY_RESOLVE_CONF}"
    echo " PATCH_MY_DHCP_SERVER_FOR_OPTION_125_WORKAROUND=${PATCH_MY_DHCP_SERVER_FOR_OPTION_125_WORKAROUND}"
    echo " PATCH_MY_DHCP_SERVER_FOR_OPTION_43_WORKAROUND=${PATCH_MY_DHCP_SERVER_FOR_OPTION_43_WORKAROUND}"
    echo " NBS_NETWORKS_TO_SNIFF=${NBS_NETWORKS_TO_SNIFF:-none}"
    echo " PATCH_MY_HOSTS=${PATCH_MY_HOSTS}"
    echo " ACS_URL_TO_USE_OPTION125=${ACS_URL_TO_USE_OPTION125}"
    echo " ACS_URL_TO_USE_OPTION43=${ACS_URL_TO_USE_OPTION43}"
    echo " PROVISIONING_CODE=${PROVISIONING_CODE}"
    echo " WAIT_INTERVAL=${WAIT_INTERVAL}"
    echo " WAIT_INTERVAL_MULTIPLIER=${WAIT_INTERVAL_MULTIPLIER}"
    echo " USE_OPTION_125_MODE=${USE_OPTION_125_MODE}"
    echo " USE_OPTION_43_MODE=${USE_OPTION_43_MODE}"
}

remove_docker_images() {
    IMAGE_VERSION=${1:-latest}
    DOCKER_IMAGES_TO_REMOVE=$(docker image ls | grep ${NBS_PROJECT}_ | grep -F ${IMAGE_VERSION} | awk '{ print $3 }') || true
    if [ "${DOCKER_IMAGES_TO_REMOVE}" != "" ]; then
	echo "${DOCKER_IMAGES_TO_REMOVE}" | xargs docker rmi -f
    fi
}

tag_images_latest() {
    if [ "${1}" != "" ]; then
	for FILE in ${NBS_PROJECT} ${NBS_ADDON}; do
	    FILES_TO_GREP="${FILES_TO_GREP} ${FILE}.nbs"
	done
	IMAGES=$(grep 'image: ' nbs.yml ${FILES_TO_GREP} | grep -v "#" | cut -d':' -f 3)
	for IMAGE in $IMAGES
	do
	    IMAGE=$(eval "echo ${IMAGE}")
	    docker tag "${IMAGE}":"${1}" "${IMAGE}":latest
	done
	display_message "${NBS_PROJECT} simulation v${1} tagged as latest!"
    fi
}

docker_simulation_cleanup () {
    sh "${0}" down
    DOCKER_IMAGES_TO_REMOVE=$(docker image ls | grep none | awk '{ print $3 }')
    if [ "${DOCKER_IMAGES_TO_REMOVE}" != "" ]; then
	echo "${DOCKER_IMAGES_TO_REMOVE}" | xargs docker rmi -f
    fi

    LATEST_VERSION=$(docker image ls | grep ${NBS_PROJECT}_ | awk '{ if($2 != "latest") {print $2} }' | sort -rV  | head -n 1)
    remove_docker_images ${VERSION}

    # Remove latest only if latest version = ${VERSION}
    if [ -n "${LATEST_VERSION}" ] && [ "${LATEST_VERSION}" = "${VERSION}" ]; then
	remove_docker_images latest
	# Tag the new latest version as latest
	LATEST_VERSION=$(docker image ls | grep ${NBS_PROJECT}_ | awk '{ if($2 != "latest") {print $2} }' | sort -rV  | head -n 1)
	tag_images_latest "${LATEST_VERSION}"
    fi
}

################################################################################
#
# MAINLINE
#
################################################################################

for FILE in ${NBS_PROJECT} ${NBS_ADDON}; do
    DOCKER_COMPOSE_FILES="${DOCKER_COMPOSE_FILES} -f ${FILE}.nbs"
done

display_settings

check_interface "${MY_DUT_INTERFACE}" "MY_DUT_INTERFACE" "69"
check_interface "${MY_UPSTREAM_INTERFACE}" "MY_UPSTREAM_INTERFACE" "25"

check_tools

display_message "Executing ${COMMAND} ..."

case ${COMMAND} in
    build)
        # Make sure only DEFAULT_IMAGE_VERSION is used for building.
        # If version was specified by the user, it should only be used when running 'up' to start a particular version of the simulation
        if [ "${VERSION}" != "${DEFAULT_IMAGE_VERSION}" ]; then
            display_message "Cannot build version ${VERSION} with ${0} v${DEFAULT_IMAGE_VERSION}."
            echo "You have exported VERSION. VERSION may only be exported to run a particular version of the simulation, that is already installed on your machine. Use 'unset VERSION' or export VERSION=${DEFAULT_IMAGE_VERSION} before building."
            exit 1
        fi
        docker_pull
        docker-compose -p ${NBS_PROJECT} -f nbs.yml ${DOCKER_COMPOSE_FILES} build --no-cache

        # Check if DEFAULT_IMAGE_VERSION is greater than the latest version found on the machine.
        # If so, we need to tag DEFAULT_IMAGE_VERSION as latest and remove the previous image tagged as latest.
        LATEST_VERSION=$(docker image ls | grep ${NBS_PROJECT}_ | awk '{ if($2 != "latest") {print $2} }' | sort -rV  | head -n 1)
        ALREADY_TAGGED=$(docker image ls | grep ${NBS_PROJECT}_ | grep -F latest | awk '{ print $2 }' | head -n1)

        if [ -z "${LATEST_VERSION}" ] || [ -z "${ALREADY_TAGGED}" ] || ([ ! "${LATEST_VERSION}" = "${VERSION}" ] && version_gt "${VERSION}" "${LATEST_VERSION}"); then
            echo "${VERSION} is the newest build and will be tagged as 'latest'."
            if [ -n "${ALREADY_TAGGED}" ]; then
		echo "Removing images with tag 'latest'..."
		remove_docker_images latest
            fi
            tag_images_latest "${VERSION}"
        else
            echo "Current latest version ${LATEST_VERSION} > ${VERSION}. This version will not be tagged as latest."
        fi
	;;
    up)
	if [ ! -f /tmp/apparmor_profile_checked ]; then
	    display_message "Checking for AppArmor profile issues ..."
	    sh "${0}" check-apparmor-profile
	else
	    display_message "Checking IP addresses ..."
	    find_addresses_for home0
	    find_addresses_for telco0
	    find_addresses_for upstream
	    echo ""
	    if [ ! -f /tmp/no_aa_tools_wished ]; then
		AA_NOTIFY_RUNNING=$(pgrep aa-notify) || true
		if [ -z "${AA_NOTIFY_RUNNING}" ]; then
		    which aa-notify && aa-notify -p || true
		fi
	    fi

	    # If the user has specified a particular version to start, we need to check if it can be found on the machine.
	    if [ "${VERSION}" != "${DEFAULT_IMAGE_VERSION}" ]; then
		for FILE in ${NBS_PROJECT} ${NBS_ADDON}; do
		    FILES_TO_GREP="${FILES_TO_GREP} ${FILE}.nbs"
		done
		IMAGES=$(grep 'image: ' nbs.yml ${FILES_TO_GREP} | grep -v "#" | cut -d':' -f 3)
		for IMAGE in $IMAGES
		do
		    IMAGE=$(eval "echo ${IMAGE}")
		    VERSION_FOUND=$(docker image ls | grep $IMAGE | grep ${VERSION}) || true
		    if [ -z "${VERSION_FOUND}" ]; then
			echo "Cannot find ${VERSION} of ${IMAGE} on your machine."
			exit 1
		    fi
		done
	    fi
	    docker-compose -p ${NBS_PROJECT} -f nbs.yml ${DOCKER_COMPOSE_FILES} up -d

	    if [ ! -z "${NBS_NETWORKS_TO_SNIFF}" ]; then
		for NETWORK_TO_SNIFF in ${NBS_NETWORKS_TO_SNIFF}; do
		    sh "${0}" wireshark "${NETWORK_TO_SNIFF}" &
		done
	    fi
	    add_helper_interface
	    wait_for_container_to_start
	    populate_hosts
	    if [ "${PATCH_MY_HOSTS}" = "YES" ]; then
		patch_hosts
	    fi
	    sh "${0}" test
	    display_message "Use \"docker attach --sig-proxy=false ${NBS_PROJECT}_acs\" to watch the openacs log ..."
	fi
	;;
    down)
	if [ ! -z "${NBS_NETWORKS_TO_SNIFF}" ]; then
	    for NETWORK_TO_SNIFF in ${NBS_NETWORKS_TO_SNIFF}; do
		INTERFACE_TO_SNIFF=$(get_interface_to_sniff "${NETWORK_TO_SNIFF}")
		PROCESS_TO_KILL=$(pgrep -f "wireshark.*${INTERFACE_TO_SNIFF}")
		if [ ! -z "${PROCESS_TO_KILL}" ]; then
		    sudo kill -9 ${PROCESS_TO_KILL} 2>/dev/null
		fi
	    done
	fi
	remove_hostfs_changes
	remove_helper_interface
	docker-compose -p ${NBS_PROJECT} -f nbs.yml ${DOCKER_COMPOSE_FILES} down
	;;
    purge_network)
	DOCKER_NETWORKS_TO_REMOVE=$(docker network ls | awk '{ print $2 }')
	if [ "${DOCKER_NETWORKS_TO_REMOVE}" != "" ]; then
	    echo "${DOCKER_NETWORKS_TO_REMOVE}" | xargs docker network rm -f 2>/dev/null || true
	fi
	# unfortunately docker is not made for network simulation; really throw away all networks ...
	sudo service docker stop
	sudo rm /var/lib/docker/network/files/local-kv.db
	if [ -f /var/lib/docker/network/files/local-kv.db ]; then
	    display_message "Sorry, could not remove file \"/var/lib/docker/network/files/local-kv.db\" ... Aborting!"
	    exit 6
	fi
	sudo service docker start
	;;
    purge)
	docker_simulation_cleanup
	DOCKER_IMAGES_TO_REMOVE=$(docker image ls | grep ${NBS_PROJECT}_ | awk '{ print $3 }')
	if [ "${DOCKER_IMAGES_TO_REMOVE}" != "" ]; then
	    echo "${DOCKER_IMAGES_TO_REMOVE}" | xargs docker rmi -f
	fi
	sh "${0}" purge_network
	;;
    remove)
	docker_simulation_cleanup
	;;
    help)
	display_help_to /dev/stdout
	;;
    wireshark)
	if [ -z "${2}" ] || [ "${2}" = "help" ]; then
	    NETWORKS=$(docker network ls | grep ${NBS_PROJECT} | awk '{ print $2 }' | sed 's/${NBS_PROJECT}_//g')
	    display_message "Available networks:"
	    echo "$NETWORKS"
	    echo
	else
	    start_wireshark "${2}"
	fi
	;;
    check-apparmor-profile)
	if [ ! -f /tmp/no_aa_tools_wished ]; then
	    touch /tmp/apparmor_profile_checked
	    check_apparmor_tools
	    ALREADY_TAGGED=$(docker image ls | grep ${NBS_PROJECT}_ | grep -F ${VERSION} | awk '{ print $3 }')
	    if [ "${ALREADY_TAGGED}" = "" ]; then
		sh "${0}" build
	    fi
	    display_message "Put all AppArmor profiles to complain mode, do not use the computer ..."
	    aa-complain /etc/apparmor.d/*
	    display_message "Using ${0} ..."
	    sh "${0}" down
	    sh "${0}" up
	    display_message "Please check the detected profile changes and allow them all  ..."
	    aa-logprof -d /etc/apparmor.d || echo "Error at checking profiles ..."
	    display_message "Enforcing all AppArmor profiles again ..."
	    aa-enforce /etc/apparmor.d/* || echo "Error at enforcing profiles ..."
	    display_message "Restarting AppArmor ..."
	    systemctl reload apparmor.service || echo "Error ar retstarting AppArmor ..."
	else
	    display_message "You did not install \"aa-genprof\" to generate an apparmor profile for this simulation or \"aa-notify\" to check installed profiled. Remove /tmp/no_aa_tools_wished to choose again ..."
	fi
	;;
    test_setup)
	sh "${0}" remove
	sh "${0}" build
	sh "${0}" up
	;;
    test)
	test_networking
	;;
    list)
	list_networks
	;;
    *)
	display_help_to /dev/stderr
	display_message "Sorry, do not know to \"${COMMAND}\" ..."
	exit 5
	;;
esac
display_message "OK, ${COMMAND} done!"
