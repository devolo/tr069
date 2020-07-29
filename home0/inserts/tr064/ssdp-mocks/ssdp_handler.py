#!/usr/bin/env python3
# Start the mock server if it is not running, otherwise terminate it.

import psutil
import os
import subprocess
import sys
import signal
import argparse
import glob
from time import sleep

pid_filename: str = "ssdp-mock-port{}.pid"
sucessfully_started = False


def check_pid_file_exists(port: int):
    return os.path.isfile(pid_filename.format(port))


def terminate_ssdp_mockservers():
    files = glob.glob('ssdp-mock-port*.pid', recursive=False)
    num_terminated = 0
    for file in files:
        with open(file) as f:
            pid = f.readline()
            try:
                psutil.Process(pid=int(pid)).terminate()
                num_terminated += 1
            except psutil.NoSuchProcess:
                pass
    # Note: We don't double check if the process terminated like we did in the mockserver_handler
    # since this doesn't work here. psutils.wait_procs waits until the timeout is finished, and only afterwards
    # The server process terminates.
    print('Terminated {} ssdp mock servers'.format(num_terminated))


def start_ssdp_mockserver(port: int):
    # ToDo: Check if process mentioned in PIDfile is actually running
    if check_pid_file_exists(args.port):
        print('Error - mock ssdp server already running at port {}'.format(args.port))
        return -1
    else:
        print('Starting SSDP mock server...')
        command: list = ['python3', 'ssdp_mock.py']
        if args.logfile:
            command.append('--logfile={}'.format(args.logfile))
        signal.signal(signal.SIGUSR1,
                      mockserver_successfully_started_signalhandler)
        p = subprocess.Popen(command, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        count = 0
        while not sucessfully_started and count < 20 and p.poll() is None:  # Abort early if child already terminated
            count += 1
            sleep(0.1)
        if sucessfully_started and p.poll() is None:
            print('SSDP mock server at port {} successfully started'.format(port))
            return 0
        else:
            print(
                'Timed out: SSDP mock server at port {} failed to start...'.format(port))
            return -1


def mockserver_successfully_started_signalhandler(signum, frame):
    global sucessfully_started
    sucessfully_started = True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='define Log location')
    parser.add_argument('--logfile', action='store')
    parser.add_argument('--terminate', action='store_true',
                        help='terminates all running ssdp-mock processes')
    parser.add_argument('--port', action='store', type=int,
                        default=1900, choices=range(1000, 65535), nargs='*')
    args = parser.parse_args()

    if args.logfile is None and not args.terminate:
        print(
            'Warning: No logfile location passed to ssdp_handler. No logs will be created')

    if args.terminate:
        terminate_ssdp_mockservers()
        sys.exit(0)
    else:
        ports = args.port
        if isinstance(ports, int):
            ports = [ports]
        print('Ports are: {}'.format(ports))
        for port in ports:
            sucessfully_started = False
            error = start_ssdp_mockserver(port)
            if (error != 0):
                terminate_ssdp_mockservers()
                sys.exit(1)
