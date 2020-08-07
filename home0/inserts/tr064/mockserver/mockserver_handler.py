#!/usr/bin/env python3
# Start the mock server if it is not running, otherwise terminate it.

import psutil
import subprocess
import sys
import argparse
import os
import glob
import requests
from time import sleep

pid_filename: str = "mockserver-port{}.pid"


def pidfile_exists(port: int):
    return os.path.isfile(pid_filename.format(port))


def is_mockserver_running(port: int):
    try:
        r = requests.get(
            'http://127.0.0.1:{}/alive-response'.format(port), timeout=0.001)
    except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
        return False
    return r.status_code == 200


def terminate_mockservers():
    files = glob.glob(pid_filename.format('*'), recursive=False)
    num_terminated = 0
    procs = []
    for file in files:
        with open(file) as f:
            pid = f.readline()
            try:
                p = psutil.Process(pid=int(pid))
                p.terminate()
                procs.append(p)
                num_terminated += 1
            except psutil.NoSuchProcess:
                pass
        os.remove(file)
    dead, alive = psutil.wait_procs(procs, timeout=3)
    for p in alive:
        p.kill()
    print('Terminated {} tr064 mock servers'.format(num_terminated))


def start_mockserver(port: int, mockdir: str, output):
    try:
        with open(pid_filename.format(args.port), 'w') as f:
            p = subprocess.Popen(['mockserver', '-p', str(port), '-m', mockdir],
                                 stdin=subprocess.PIPE, stdout=output, stderr=subprocess.PIPE)
            f.write(str(p.pid))
    except OSError:
        print('Writing PID file failed.')
        return -1
    except Exception as e:
        print('Error: {}'.format(str(e)))
        terminate_mockservers()
        return -1
    count = 0
    while count < 50 and not is_mockserver_running(port):
        sleep(0.1)
    if is_mockserver_running(port):
        return 0
    else:
        return -1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='define Log location')
    parser.add_argument('--logfile', action='store',
                        type=argparse.FileType('w'))
    parser.add_argument('--terminate', action='store_true',
                        help='terminates all running tr064-mock processes')
    parser.add_argument('--port', action='store', type=int,
                        default=[49000], choices=range(1000, 65535), nargs='*')
    parser.add_argument('--mockdir', action='store', type=str, default=[
                        'mocks/'], nargs='*', help='Directory containing mocks to be served. Position must match port')
    args = parser.parse_args()

    if args.terminate:
        terminate_mockservers()
        sys.exit(0)
    ports = args.port
    mockdirs = args.mockdir
    if len(ports) != len(mockdirs):
        print(
            'Error: You must specify one mockdir for every server (specified with --port)')
        sys.exit(1)
    print('Starting {} mockservers'.format(len(ports)))
    for mockdir in mockdirs:
        if not os.path.isdir(mockdir):
            print('Error: parameter --mockdir {} is not a directory'.format(mockdir))
            sys.exit(1)

    if args.logfile:
        # ToDo Does stdout redirection to file work in append mode by default for subprocess?
        output = args.logfile
    else:
        output = subprocess.PIPE

    for i in range(0, len(ports)):
        # ToDo: Can this be done more pythonic?
        error = start_mockserver(ports[i], mockdirs[i], output)
        if error != 0:
            print('Failed to start Mockserver at Port {} with mockdir {}'.format(
                ports[i], mockdirs[i]))
            terminate_mockservers()
            sys.exit(1)
    sys.exit(0)
