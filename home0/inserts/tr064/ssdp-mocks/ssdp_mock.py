#!/usr/bin/env python3
# A Python Script to create a mock SSDP server that answers to a SSDP discovery request

import socket
import sys
import logging
import signal
import os
import argparse
from datetime import date
from time import gmtime

terminate = False
logger = logging.getLogger(__name__)
pid_filename: str = "ssdp-mock-port{}.pid"



def inform_parent_failed():
    """ Inform Parent that server has finished setting up and is now ready"""
    parent_pid = os.getppid()
    if parent_pid == 1:
        return True
    os.kill(parent_pid, signal.SIGUSR1)
    return False


class MockSSDPServer():
    def __init__(self, ip="0.0.0.0", port=1900, tr64Ip="127.0.0.1",
                 tr64Port=49000, timeout=5):
        self.ip = ip
        self.port = port
        self.cachecontrol = 1800
        self.tr64Ip = tr64Ip
        self.tr64Port = tr64Port
        self.servernames = ["Fritzbox 747", "Speedport 42"]
        self.urns = ["urn:dslforum-org:service:WANDSLInterfaceConfig:1#X_AVM-DE_GetDSLInfo",
                     "urn:telekom-de:device:TO_InternetGatewayDevice:2#GetParameterValues"]
        self.count = 0

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.setsockopt(
            socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)  # ttl 2
        self.sock.settimeout(timeout)

        addr = socket.inet_aton('239.255.255.250')  # multicast address
        interface = socket.inet_aton(self.ip)
        self.sock.setsockopt(
            socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, addr + interface)

        self.sock.bind((self.ip, self.port))

    def check(self, data, addr):
        logger.info('SSDP Packet received from {}'.format(addr))
        logger.info(data)
        decoded = data.decode("utf8").replace('\r', '').split('\n')
        msgtype, decoded = decoded[0], decoded[1:]
        decodeddict = {x.split(':',  1)[0].upper(): x.split(
            ':', 1)[1].strip(' ') for x in decoded if x != ''}

        if 'M-SEARCH' in msgtype:
            st = decodeddict.get('ST')

            response = ['HTTP/1.1 200 OK',
                        'CACHE-CONTROL: max-age={}'.format(self.cachecontrol),
                        'LOCATION: http://{}:{}/description.xml'.format(
                            self.tr64Ip, self.tr64Port),
                        'SERVER: {}'.format(self.servernames[self.count % 2]),
                        'Date: {}'.format(date.today().strftime(
                            "%a, %d %b %Y %H:%M:%S")),
                        'EXT: ',
                        'ST: {}'.format(self.urns[self.count % 2]),
                        'USN: {}'.format("uuid:00000000-0000-0002-0000-44fffffffe3b38ffffffa2ffffffb4::urn:telekom-de:device")]

            if st == "urn:dslforum-org:device:InternetGatewayDevice:1":
                # Only increase count on AVM SSDP receive, since we always send out both requests
                self.count += 1

            response.extend(('', ''))
            response = '\r\n'.join(response)

            self.sock.sendto(response.encode(), addr)
            logger.info('SSDP Packet sent to {}'.format(addr))

    def start(self):
        logger.info('SSDP Server Running...')
        countTimeout = pcount = 0
        if inform_parent_failed():
            logger.error(
                'Parent already dead before successful startup finished.')
            return
        while not terminate:
            try:
                if countTimeout % 5 == 0:
                    logger.info('Ssdp Poll... {} pings'.format(pcount))
                    pcount = 0
                    countTimeout = 1
                data, addr = self.sock.recvfrom(1024)
                pcount += 1
                self.check(data, addr)
            except socket.timeout:
                countTimeout += 1
                continue
            except Exception as e:
                logger.info('error occurred ' + str(e))


def service_shutdown(signum, frame):
    global terminate
    terminate = True


def pidfile_exists(port: int):
    return os.path.isfile(pid_filename.format(port))


def main():
    parser = argparse.ArgumentParser(description='define Log location')
    parser.add_argument('--logfile', action='store')
    parser.add_argument('--port', action='store', type=int, default=1900,
                        choices=range(1000, 65535))
    args = parser.parse_args()
    logger.setLevel(logging.DEBUG)
    if args.logfile:
        ch = logging.FileHandler(filename=args.logfile)
    else:
        ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    logger.addHandler(ch)
    if pidfile_exists(args.port):
        logger.error(
            "Error: PID file found - process already running - shutting down...")
        sys.exit(1)
    else:
        signal.signal(signal.SIGTERM, service_shutdown)
        signal.signal(signal.SIGINT, service_shutdown)
        try:
            with open(pid_filename.format(args.port), 'w') as f:
                f.write(str(os.getpid()))
            server = MockSSDPServer()
            server.start()
        except OSError:
            logger.error('Writing PID file failed.')
        except Exception as e:
            logger.error('Error: {}'.format(str(e)))

    server.sock.close()
    logger.info("Shutting down Ssdp server")
    if pidfile_exists(args.port):
        logger.info("Removing PID file Ssdp server")
        os.remove(pid_filename.format(args.port))
    ch.flush()
    ch.close()


if __name__ == "__main__":
    sys.exit(main())
