##
# Estore func
#

import sys
import time

import threading
import Queue

from gevent import monkey
from gevent.pool import Pool
import gevent

monkey.patch_all(thread=True,  sys=True)


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


#  read - recieve message from world
#  send - send message to world
#  log  -  logging anything


def add_input(input_queue):

    while True:
        msg = read()

        if msg == "stop_async_worker":
            send(msg)
        else:
            input_queue.put(msg)


def process(args):

    msg, t = args

    log("start working..")
    log("get message: " + msg)

    _b = time.time()

    resp = msg

    gevent.sleep(t)

    send(resp)

    log("message send: {} ".format(time.time() - _b))


def main(num, t):

    pool = Pool(int(num))

    input_queue = Queue.Queue()

    input_thread = threading.Thread(target=add_input, args=(input_queue,))
    input_thread.daemon = True
    input_thread.start()

    while 1:

        msg = input_queue.get()

        if not msg:
            break

        g = pool.spawn(process, (msg, t))
        g.link_exception(exception_callback)


def exception_callback(g):
    """Process gevent exception"""
    try:
        g.get()
    except Exception as exc:
        log("error : {} ".format(exc))
        send(exc)

if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]))
