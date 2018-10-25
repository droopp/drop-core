#
# Python actor example
#

import sys
import time

# API


def read():
    line = sys.stdin.readline()
    return line.strip()


def log(m):
    sys.stderr.write("{}: {}\n".format(time.time(), m))
    sys.stderr.flush()


def send(m):
    sys.stdout.write("{}\n".format(m))
    sys.stdout.flush()


# Process - actor
#  read - recieve message from world
#  send - send message to world
#  log  -  logging anything


def main(t):
    while 1:
        line = read()
        if not line:
            break

        log("start working..")
        log("get message: " + line)

        resp = "{}".format(line)

        send(resp)

        log("message send: {}".format(resp))


if __name__ == "__main__":
    main(sys.argv[1])
