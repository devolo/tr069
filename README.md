# TR-069 - network breadboarding system (NBS) v1.3.5

a virtual TR-069 test network to connect your device under test (DUT) to openACS or GenieACS

  * [Overview](#overview)
  * [Prerequisites](#prerequisites)
    + [Use a Debian like system](#use-a-debian-like-system)
    + [Issues using docker and AppArmor](#issues-using-docker-and-apparmor)
    + [Setup the VLAN at your switch](#setup-the-vlan-at-your-switch)
      - [Configure the VLAN](#configure-the-vlan)
      - [Configure the tagging](#configure-the-tagging)
    + [Declare the interfaces to use](#declare-the-interfaces-to-use)
      - [DUT via MY_DUT_INTERFACE](#dut-via-my-dut-interface)
      - [Upstream network via MY_UPSTREAM_INTERFACE](#upstream-network-via-my-upstream-interface)
    + [DHCP and Network manager](#dhcp-and-network-manager)
    + [Upstream network and default gateway behavior](#upstream-network-and-default-gateway-behavior)
    + [Testing the setup](#testing-the-setup)
  * [Running](#running)
    + [Choose the version of the NBS](#choose-the-version-of-the-nbs)
  * [Networking](#networking)
  * [Certificates](#certificates)
  * [Logging](#logging)
  * [Instances and networks](#instances-and-networks)
    + [telco0 network:](#telco0-network-)
    + [home0 network:](#home0-network-)
    + [interconnection network:](#interconnection-network-)
    + [upstream network:](#upstream-network-)
  * [Howto examine and debug](#howto-examine-and-debug)
  * [Connect DUTs to ACS](#connect-duts-to-acs)
    + [openACS](#openacs)
    + [GenieACS](#genieacs)
  * [GUI credentials](#gui-credentials)
    + [webserver](#webserver)
    + [openACS](#openacs-1)
    + [GenieACS](#genieacs-1)

## Overview
This repository contains everything to create and configure a virtual TR-069 test network utilizing docker to run openACS, GenieACS, XMPP, STUN, a web server for up and download and a syslog server in combination with different private and public networks protected by gateways and firewalls to be able to connect and test your DUT.

The intended use case here at devolo is to test TR-069 in combination with our products. For productive uses the credentials and the setup of this network breadboarding system (NBS) is highly insecure.

Unfortunately, currently only IPv4 for name services and firewall is supported and you need superuser rights to use this.

Nevertheless the NBS is way more than that, you are able to easily extend your virtual setup by plugging in networks and container running real world applications like integrated circuits on a breadboard.

![Overview](tr069_NBS.png?raw=true "Overview")

## Prerequisites

### Use a Debian like system
Currently the NBS is mainly used with Ubuntu 18.04, but any Debian like OS should also do the job. Feel free to participate and extend it to other systems.

### Issues using docker and AppArmor
Several issues have been reported which are rooted to the usage of docker in combination with AppArmor.

They vary from some failures on some systems in some containers like 'there is no DHCP for GenieACS in the telco0 network, but all other containers are working' to 'from my HOST system I can not ping telco0.public, but the command `dig telco0.public` on my HOST resolves the IP address of telco0.public, and then pinging this address works'.

Some workarounds have been added to the startup script, but nevertheless these are only workarounds and can not be complete. If you face such issues, please try to deinstall AppArmor, recheck the issue, then report the issue with your findings and reinstall AppArmor afterwards if wished.

### Setup the VLAN at your switch
You should choose a VLAN to use the NBS to not accidentally put another DHCP server to you network. The chosen VLAN must be free and unused in your computer. Docker will create the VLAN for you, but you have to configure the VLAN properly at your switch to connect a DUT which is not capable to use VLANs.

#### Configure the VLAN
Please take a look at the example configuration of VLAN 66 for docker simulation at the GUI of a networking switch:
![Example configuration](VLAN_configuration.png?raw=true "Example configuration")

#### Configure the tagging
Set up the tagging for your DUT. Please take a look at the tagging and untagging of VLAN 66 at the GUI of a networking switch, and please make sure that the untagged data traffic is only sent to the DUT:
![Example tagging](VLAN_setup_tagging.png?raw=true "Example tagging")
Here, the HOST running docker is connected to port 8, the Ethernet frames are tagged, indicated by `T` in the UI. The DUT is normally not capable of VLAN tagging. Here the  DUT is connected to port 2, indicated by `U`. Please make sure that the untagged data traffic is only sent to the DUT. In this example only one `U` is present, all other ports but the HOST port are excluded `E` from VLAN 66.

### Declare the interfaces to use
#### DUT via MY_DUT_INTERFACE
Your HOST will use the intra/internet to set up the TR-069 test environment automatically, but must know where your DUT is connected to.

E.g. if your DUT is connected via the switch to the physical interface named 'eth0' and you want to use VLAN 66 for your communication, please use `export MY_DUT_INTERFACE=eth0.66` before starting or testing the network. Please use the VLAN you configured to your switch.

#### Upstream network via MY_UPSTREAM_INTERFACE
The NBS can be connected to an external network for services like NTP, e.g. the network using VLAN 666. Please use something like `export MY_UPSTREAM_INTERFACE=eth0.666` before starting or testing the network. The VLAN switch must be configured similarly as for the MY_DUT_INTERFACE.

### DHCP and network manager

Normally you will have a running network manager on your Ubuntu HOST which will be responsible to integrate the name server of the home0 gateway into your system. If this is not the case, you can `export PATCH_MY_RESOLVE_CONF=YES` to patch /ect/resolf.conf automatically, so you are able to resolve names. This patch will be removed on stopping the NBS.

### Upstream network and default gateway behavior

If you want to be able to use the upstream network connected via MY_UPSTREAM_INTERFACE from your HOST via the NBS then you can `export MY_UPSTREAM_NETWORK_SHALL_BE_REACHABLE_THROUGH_THE_SIMULATED_NETWORK=YES`. If you want to route all your network traffic through the NBS you can `export MY_UPSTREAM_INTERFACE_ACCEPTS_DEFAULT_GW=YES`.

### Testing the setup
To test the network, just run `sudo -E sh simulate_tr-069.sh test_setup`.

All images and containers are then removed, newly build and started. The system will wait some time for the ACS to start and check some network connections.

To only run the basic tests after the system is build and up run `sudo -E sh simulate_tr-069.sh test`.

## Running

To start the network, just run `sudo -E sh simulate_tr-069.sh up`.

To stop the network, run `sudo -E sh simulate_tr-069.sh down`.

### Choose the version of the NBS
From version 1.3.2 on you are able to switch quickly between newer versions of the NBS and get back to older ones without the need of purging and rebuilding everything from scratch.
To get a newer version just stop the NBS, pull the new one using `git pull` and start the network again. Then you will have got multiple versions of the docker system installed on your machine.
To choose the version of the NBS to be used, just stop the current one and use e.g. `export VERSION=1.3.2` to start the particular version of NBS, in this case 1.3.2.

## Networking

Your HOST is connected by an virtual Ethernet interface to the docker network. If you do not set the environment variable MY_HELPER_INTERFACE, the default name is 'sim-tr069-net'. simulate_tr-069.sh searches for the first free 192.168.XXX.0/24 network and uses this for home0. Your HOST system will get an IP address from the home0 gateway using DHCP, your DUTs will also receive addresses from 192.168.XXX.100-110. The domain used for the home0 network is 'home0.intern'.

The simulated internet uses the domain '.public' for all connected containers, e.g. to ping the telco0 gateway from the HOST you can use the command `ping telco0.public`.

The NBS consists currently of three separated parts; one home network, one telco network and one interconnection network to connect all the simulated networks. All networks are guarded by a gateway. There are two types of gateways: One to be attached to the physical world using MY_DUT_INTERFACE, and the other for pure simulated interconnection. These three parts are connected to an upstream network, which can provide e.g. internet access or NTP.

## Certificates

All certificates used in this setup are locally generated at the nginx container (OK, that is not the correct place to do so, but it is the place where they are used, because the nginx terminates all encrypted connections). Two root CAs are self signed, two intermediate CAs are signed by one of the root CAs so that certificate chaining can be tested, and client and server certificates are generated for the DUT and telco0.public from each of the different CAs. All the certificates and necessary keys are stored persistently and uploaded to the web server for easy access.

## Logging

All containers of the NBS are logging their events and messages using rsyslog. There is also a dedicated container to collect all logs named 'rsyslog.public'.

## Instances and networks

Currently, there are the following instances present in the following networks:

### telco0 network:
* telco0      : gateway of the telco; uses upstream as default gateway
* stun        : serves as helper to stimulate the CPE
* nginx       : [nginx 1.16.0](http://nginx.org/download/nginx-1.16.0.tar.gz) serves as proxy to the different services (acs, web, genieacs) and terminates all encrypted connections
* acs         : [openACS 4.2.3.GA](https://sourceforge.net/projects/openacs/), compiled locally
* acsdb       : mysql database for openACS
* web         : apache serves as web server to upload and download data to and from the CPE
* genieacs    : [GenieACS](https://github.com/genieacs/genieacs/) with database

The used database holds all openACS configuration scrips and device data and is persistent. To clean up use `docker volume rm tr069_acsdb`.

### home0 network:
* home0       : internet gateway device (IGD) using UPNP; uses upstream as default gateway; serve files in /tftpboot
* probe1      : to examine the network it is attached to
* DUT         : the device under test is connected to the home0 network using a VLAN and a switch

### interconnection network:
* home0       : gateway of the customer; firewall shields the private network
* telco0      : gateway of the telco; firewall shields the private network
* upstream    : gateway used for upstream data; firewall shields the interconnection network
* xmpp        : serves as helper to stimulate the CPE
* rsyslog     : collects all the logs from all instances of the NBS

### upstream network:
 is directly connected to the devolo testing network or the 'real' internet

## Howto examine and debug

To:
* examine one instance itself, e.g. the ACS, simply use `docker exec -i -t tr069_acs /bin/bash`.
* interactively examine the acsdb, use `mysql -u root -p -h acsdb` in the telco0 network, and use 'password' as password.
* extract the scripts from openACS, use `mysqldump -u root -p ACS ScriptBean` with 'password' as password at the acsdb.
* up and download files to the telco0 web server, use 'http://telco0.public' or 'https://telco0.public' as URL, user 'Admin', password 'devolo', or user 'test_123@devolo.de', password 'p@U_?fw+'.
* follow the ACS log use `docker attach --sig-proxy=false tr069_acs`. Hitting CTRL-C will detach from that container.
* see the complete log from all container use `docker-compose logs`. You can simply filter by e.g. `docker-compose logs| grep acs_1`.
* sniff the network traffic e.g. in the telco0 network, use `sudo -E sh simulate_tr-069.sh wireshark telco0`; to get all available networks, use `sudo -E sh simulate_tr-069.sh wireshark`
* start sniffing automatically at 'up', use e.g. `export TR069_NETWORKS_TO_SNIFF="home0 internet telco0"`; keep in mind that 'down' destroys the trace
* serve some files using TFTP to e.g. the DUT in the home0 network, copy them with `docker cp ${MY_FILE} home0:/tftpboot/${MY_FILE}` to the container
* examine the syslog, simply use `docker exec -i -t tr069_rsyslog /bin/bash` in a different terminal and use tools like 'cat /var/log/syslog'. This works in every container.

## Connect DUTs to ACS

Simply store the URL and the necessary credentials in the DUT.

### openACS
* 'http://telco0.public:9000/openacs/acs'
* 'https://telco0.public:9001/openacs/acs', server and client certificate needed
* 'https://telco0.public:9002/openacs/acs', server certificate needed
* 'https://telco0.public:9010/openacs/acs', basic authentication, user 'Admin', password 'devolo'
* 'https://telco0.public:9011/openacs/acs', digest authentication, user 'Admin', password 'devolo'
### GenieACS
* 'http://telco0.public:7547/' or 'http://telco0.public:7070/'
* 'http://telco0.public:10000', basic authentication
* 'http://telco0.public:10001', digest authentication
* 'https://telco0.public:10002', server and client certificate needed
* 'https://telco0.public:10003', server and client certificate needed, including basic authentication
* 'https://telco0.public:10004', server certificate needed
* 'https://telco0.public:10005', server certificate needed, including basic authentication

## GUI credentials

### webserver
*  'http://telco0.public', user 'Admin', password 'devolo'.
*  'https://telco0.public', user 'Admin', password 'devolo'.
### openACS
*  'http://telco0.public:9000/openacs', HTTP
*  'https://telco0.public:9001/openacs', HTTPS with client certificate
*  'https://telco0.public:9002/openacs', HTTPS without client certificate
### GenieACS
*  'http://telco0.public:7070', HTTP, user 'admin', password 'admin'.
