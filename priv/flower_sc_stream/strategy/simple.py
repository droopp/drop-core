
#
# Simple strategy like systemd
# Run func on all nodes or main node
#

import sys
import time


def read():
    line = sys.stdin.readline()
    return line.strip()


def log(m):
    sys.stderr.write("{}: {}\n".format(time.time(), m))
    sys.stderr.flush()


def send(m):
    sys.stdout.write("{}\n".format(m))
    sys.stdout.flush()


def do(p, pstats, m_nodes, pflows):
    start_init_flows(p, pstats, m_nodes, pflows)


def start_init_flows(p, pstats, m_nodes, pflows):

    for f in pflows:
        try:
            f_name, f_active, f_priority, f_ppools = f.get("name"),\
                f.get("active"), f.get("priority"),\
                [[y.get("cmd").split("::")[3] for y in x.get("cook")
                if y.get("cmd").split("::")[2] == "start_pool"]
                for x in f.get("scenes")
                if x["name"] == f.get("start_scene")][0]
        except Exception as e:
            log("bad flow structure {}: {}".format(f, e))
            continue

        log("read flow {} {} {} {}".format(f_name, f_active, f_priority, f_ppools))

        # if flow not active stop on all nodes
        if f_active == 0:
            log("stop on all nodes..{}".format(f_name))
            send("system::all::{}::stop".format(f_name))

        elif f_active == 1:
            # check already started
            first_start = True

            # need first start for priority 0
            if f_priority == 0:
                log("flow {} first start {}".format(f_name, first_start))
                send("system::all::{}::start".format(f_name))

            elif f_priority == 1:
                log("start on main node {} {}".format(m_nodes[0], f_name))
                # force clear
                send("system::{}::{}::start".format(m_nodes[0], f_name))
                [send("system::{}::{}::stop".format(x, f_name)) for x in m_nodes[1:]]

            for k, v in pstats.iteritems():

                if k not in m_nodes:
                    continue

                if set(f_ppools).issubset(set([x[1] for x in v])):

                    log("on node {} flow {} is started".format(k, f_name))
                    # send("system::{}::{}::start".format(k, f_name))

                    first_start = False

                elif set([x[1] for x in v]).issubset(set(f_ppools)):
                    log("on node {} flow {} is NOT started".format(k, f_name))

                    # force clear
                    # send("system::{}::{}::stop".format(k, f_name))
                    first_start = False or first_start
