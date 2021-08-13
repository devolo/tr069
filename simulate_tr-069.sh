#!/bin/sh

# halt on errors, please
set -e
#set -x

DEFAULT_IMAGE_VERSION="1.3.6"
SCRIPT_VERISON="1.3.7"

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
VERSION=${VERSION:-$DEFAULT_IMAGE_VERSION}
MY_DUT_INTERFACE=${MY_DUT_INTERFACE:-enp0s25}
HOME0_OWN_IP_ADDRES_BYTE=${HOME0_OWN_IP_ADDRES_BYTE:-100}

export MY_DUT_INTERFACE
export VERSION
export HOME0_OWN_IP_ADDRES_BYTE

COMMAND=${1:-"help"}
TR069_NETWORKS_TO_SNIFF=${TR069_NETWORKS_TO_SNIFF:-""}

RESOLV_FILE=/etc/resolv.conf
HOSTS_FILE=/etc/hosts

WIRESHARK_HOSTS_FILE=~/.config/wireshark/hosts

START_PATTERN="####TR069START####"
END_PATTERN="###TR069END###"

HOSTS_TO_TEST="home0"

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
    * remove        : executes 'down' and removes all tr069 images of current version and latest
    * purge_network : stopping docker daemon, removing all networks and restarting the daemon again; use with care
    * purge         : executes 'down' and removes all tr069 images
    * test_setup    : executes 'remove', 'build' and 'up'
    * wireshark     : starts wireshark to sniff the given network; if no network name given, displays available network names
    * list          : list network names
    * help          : displays this text
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

# to throw away the added hosts easily, insert them between the start and end pattern
# this is not atomic and may fail if some changes to WIRESHARK_HOSTS_FILE are done by the
# system during populate_hosts ...
populate_hosts() {
    CONTAINERS=$(docker ps --format '{{.Names}}'| grep tr069_ )

    mkdir -p "$(dirname ${WIRESHARK_HOSTS_FILE})"
    echo ${START_PATTERN}>>${WIRESHARK_HOSTS_FILE}
    for CONTAINER in ${CONTAINERS}; do
	HOSTS=$(docker exec "${CONTAINER}" sh -c "cat /etc/hosts" 2>/dev/null) || true
	WIRESHARK_DATA=$(echo "${HOSTS}" | grep -v localhost | grep -v ::) || true
	echo "${WIRESHARK_DATA}">>${WIRESHARK_HOSTS_FILE}
    done
    echo ${END_PATTERN}>>${WIRESHARK_HOSTS_FILE}
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

# errors were seen due to an old ubuntu:18.04 image ... pull it to be up to date
docker_pull() {
    docker pull ubuntu:18.04
    docker pull ubuntu:12.04
    echo ""
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
    NETWORK_LIST=$(docker network ls | grep tr069_ | awk -v _=${NETWORK_ITEM_GLUE} '{ print $1_$2 }')
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
    display_message "Settings of v${SCRIPT_VERISON} (default image v${DEFAULT_IMAGE_VERSION}):"
    echo " VERSION=${VERSION} ; image version to use"
    echo " MY_DUT_INTERFACE=${MY_DUT_INTERFACE}"
    echo " TR069_NETWORKS_TO_SNIFF=${TR069_NETWORKS_TO_SNIFF:-none}"
    echo " HOME0_OWN_IP_ADDRES_BYTE=${HOME0_OWN_IP_ADDRES_BYTE}"
}

remove_docker_images() {
    IMAGE_VERSION=${1:-latest}
    DOCKER_IMAGES_TO_REMOVE=$(docker image ls | grep tr069_ | grep -F ${IMAGE_VERSION} | awk '{ print $3 }')
    if [ "${DOCKER_IMAGES_TO_REMOVE}" != "" ]; then
	echo "${DOCKER_IMAGES_TO_REMOVE}" | xargs docker rmi -f
    fi
}

docker_simulation_cleanup () {
    sh "${0}" down
    DOCKER_IMAGES_TO_REMOVE=$(docker image ls | grep none | awk '{ print $3 }')
    if [ "${DOCKER_IMAGES_TO_REMOVE}" != "" ]; then
	echo "${DOCKER_IMAGES_TO_REMOVE}" | xargs docker rmi -f
    fi

    LATEST_VERSION=$(docker image ls | grep tr069_ | awk '{ if($2 != "latest") {print $2} }' | sort -rV  | head -n 1)
    remove_docker_images ${VERSION}

    # Remove latest only if latest version = ${VERSION}
    if [ -n "${LATEST_VERSION}" ] && [ "${LATEST_VERSION}" = "${VERSION}" ]; then
	remove_docker_images latest
	# Tag the new latest version as latest
	LATEST_VERSION=$(docker image ls | grep tr069_ | awk '{ if($2 != "latest") {print $2} }' | sort -rV  | head -n 1)
	tag_images_latest "${LATEST_VERSION}"
    fi
}

tag_images_latest() {
    if [ "${1}" != "" ]; then
	IMAGES=$(grep 'image: ' docker-compose.yml | grep -v "#" | cut -d':' -f 2)
	for IMAGE in $IMAGES
	do
	    docker tag "${IMAGE}":"${1}" "${IMAGE}":latest
	done
	display_message "TR-069 simulation v${1} tagged as latest!"
    fi
}

################################################################################
#
# MAINLINE
#
################################################################################

display_settings

check_interface "${MY_DUT_INTERFACE}" "MY_DUT_INTERFACE" "69"

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
        docker-compose build --no-cache

        # Check if DEFAULT_IMAGE_VERSION is greater than the latest version found on the machine.
        # If so, we need to tag DEFAULT_IMAGE_VERSION as latest and remove the previous image tagged as latest.
        LATEST_VERSION=$(docker image ls | grep tr069_ | awk '{ if($2 != "latest") {print $2} }' | sort -rV  | head -n 1)
        ALREADY_TAGGED=$(docker image ls | grep tr069_ | grep -F latest | awk '{ print $2 }' | head -n1)

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
	    echo ""
	    if [ ! -f /tmp/no_aa_tools_wished ]; then
		AA_NOTIFY_RUNNING=$(pgrep aa-notify) || true
		if [ -z "${AA_NOTIFY_RUNNING}" ]; then
		    which aa-notify && aa-notify -p || true
		fi
	    fi

	    # If the user has specified a particular version to start, we need to check if it can be found on the machine.
	    if [ "${VERSION}" != "${DEFAULT_IMAGE_VERSION}" ]; then
		IMAGES=$(grep 'image: ' docker-compose.yml | grep -v "#" | cut -d':' -f 2)
		for IMAGE in $IMAGES
		do
		    VERSION_FOUND=$(docker image ls | grep $IMAGE | grep ${VERSION})
		    if [ -z "${VERSION}" ]; then
			echo "Cannot find ${VERSION} on your machine."
			exit 1
		    fi
		done
	    fi

	    docker-compose up -d

	    if [ ! -z "${TR069_NETWORKS_TO_SNIFF}" ]; then
		for NETWORK_TO_SNIFF in ${TR069_NETWORKS_TO_SNIFF}; do
		    sh "${0}" wireshark "${NETWORK_TO_SNIFF}" &
		done
	    fi
	    populate_hosts
	    display_message "Use \"docker attach --sig-proxy=false tr069_home0\" to watch the home0 gateway log ..."
	fi
	;;
    down)
	if [ ! -z "${TR069_NETWORKS_TO_SNIFF}" ]; then
	    for NETWORK_TO_SNIFF in ${TR069_NETWORKS_TO_SNIFF}; do
		INTERFACE_TO_SNIFF=$(get_interface_to_sniff "${NETWORK_TO_SNIFF}")
		PROCESS_TO_KILL=$(pgrep -f "wireshark.*${INTERFACE_TO_SNIFF}")
		if [ ! -z "${PROCESS_TO_KILL}" ]; then
		    sudo kill -9 ${PROCESS_TO_KILL} 2>/dev/null
		fi
	    done
	fi
	remove_hostfs_changes
	docker-compose down
	;;
    purge_network)
	DOCKER_NETWORKS_TO_REMOVE=$(docker network ls | awk '{ print $2 }')
	if [ "${DOCKER_NETWORKS_TO_REMOVE}" != "" ]; then
	    echo "${DOCKER_NETWORKS_TO_REMOVE}" | xargs docker network rm -f 2>/dev/null || true
	fi
	# unfortunately docker is not made for network simulation; really throw away all networks ...
	sudo service docker stop
	sudo rm /var/lib/docker/network/files/local-kv.db
	sudo service docker start
	;;
    purge)
	docker_simulation_cleanup
	DOCKER_IMAGES_TO_REMOVE=$(docker image ls | grep tr069_ | awk '{ print $3 }')
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
	    NETWORKS=$(docker network ls | grep tr069 | awk '{ print $2 }' | sed 's/tr069_//g')
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
	    ALREADY_TAGGED=$(docker image ls | grep tr069_ | grep -F ${VERSION} | awk '{ print $3 }')
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
