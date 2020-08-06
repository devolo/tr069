#!/usr/bin/env python3
# A Python Script to create a mock SSDP server that answers to a SSDP discovery request

import argparse
import datetime
import logging
import signal
import socket
import sys


def setup_logger(logfile: str):
    logger.setLevel(logging.DEBUG)
    if logfile:
        ch = logging.FileHandler(filename=logfile)
    else:
        ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    logger.addHandler(ch)


class MockSSDPServer:
    def __init__(self, ip="0.0.0.0", port=1900, location_ip="127.0.0.1", location_port=49000, timeout=5, server_name="Speedport Smart 3",
                 st="urn:telekom-de:device:TO_InternetGatewayDevice:2"):
        self.ip = ip
        self.port = port
        self.location_ip = location_ip
        self.location_port = location_port
        self.timeout = timeout
        self.server_name = server_name
        self.st = st
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # close socket on sigint and sigterm
        signal.signal(signal.SIGINT, self.stop)
        signal.signal(signal.SIGTERM, self.stop)

    @staticmethod
    def _check(data: bytes):
        logger.info(data)
        decoded = data.decode("utf8").replace('\r', '').split('\n')
        msgtype, decoded = decoded[0], decoded[1:]
        return 'M-SEARCH' in msgtype

    def _send_mock_response(self, addr: str):
        response = ['HTTP/1.1 200 OK',
                    'CACHE-CONTROL: max-age=1800',
                    'LOCATION: http://{}:{}/description.xml'.format(
                        self.location_ip, self.location_port),
                    'SERVER: {}'.format(self.server_name),
                    'Date: {}'.format(datetime.date.today().strftime(
                        "%a, %d %b %Y %H:%M:%S")),
                    'EXT: ',
                    'ST: {}'.format(self.st),
                    'USN: {}{}'.format("uuid:00000000-0000-0002-0000-44fffffffe3b38ffffffa2ffffffb4::",self.st)]

        response.extend(('', ''))
        response = '\r\n'.join(response)
        self.sock.sendto(response.encode(), addr)
        logger.info('SSDP Packet sent to {}'.format(addr))

    def start(self):
        try:
            addr = socket.inet_aton('239.255.255.250')  # multicast address
            interface = socket.inet_aton(self.ip)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)  # ttl 2
            self.sock.settimeout(self.timeout)
            self.sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, addr + interface)
            self.sock.bind((self.ip, self.port))
        except socket.error as e:
            logger.error(f"Could not open socket: {e}")
            sys.exit(1)

        logger.info('SSDP Server Running...')
        while True:
            try:
                data, addr = self.sock.recvfrom(1024)
                msearch_received = self._check(data=data)
                if msearch_received:
                    self._send_mock_response(addr=addr)
            except socket.timeout:
                logger.info('socket timeout encountered')

    def stop(self, signum, frame):
        while True:
            try:
                self.sock.close()
                sys.exit(0)
            except socket.error:
                sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='Simple Mockserver for SSDP discovery')
    parser.add_argument('--logfile', action='store', help="Write output to <logfile>")
    parser.add_argument('--port', action='store', type=int, default=1900, choices=range(1000, 65535), help="Server port for SSDP discovery.")
    parser.add_argument('--st', action='store', default="urn:telekom-de:device:TO_InternetGatewayDevice:2",
                        help="Mock value for the ST parameter in the SSDP response.")
    parser.add_argument('--server-name', dest="server_name", action='store', help="Mock value for the SSDP server name.")
    parser.add_argument('--location-ip', dest="location_ip", action='store', help="Mock value for the IP address inside the LOCATION parameter.")
    parser.add_argument('--location-port', dest="location_port", action='store', type=int, default=49000,
                        help="Mock value for the Port inside the LOCATION parameter.")

    args = parser.parse_args()
    setup_logger(logfile=args.logfile)

    try:
        server = MockSSDPServer(location_ip=args.location_ip, location_port=args.location_port, server_name=args.server_name, st=args.st)
        server.start()
    except Exception as e:
        logger.error('Error: {}'.format(str(e)))


if __name__ == "__main__":
    logger = logging.getLogger(__name__)
    sys.exit(main())
