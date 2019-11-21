
#
# Elastic strategy like FaaS
# Run func if need and scale out + migrate
#

import sys
import time
from operator import mul
import sqlite3
import math


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

    pstats = get_stats_decrease(p, pflows)

    log("start decrease flows..")

    decrease_ppools(p, pstats, m_nodes, pflows)

    log("start rebalance flows..")

    start_rebalance_flow(p, m_nodes, pflows)


def start_init_flows(p, pstats, m_nodes, pflows):

    for f in pflows:

        try:
            f_name, f_active, f_priority, f_ppools, f_count, f_ram, f_subs = f.get("name"),\
                f.get("active"), f.get("priority"),\
                [[y.get("cmd").split("::")[3] for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_pool"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0],\
                [[int(y.get("cmd").split("::")[4]) for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_pool"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0],\
                [[int(y.get("cmd").split("::")[4].split(" ")[1][:-1]) for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_all_workers"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0],\
                [[y.get("cmd") for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "subscribe"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0]

        except Exception as e:
            log("bad flow structure {}: {}".format(f, e))
            continue

        log("read flow {} {} {} {} {} {}".format(f_name, f_active, f_priority, f_ppools, f_count, f_ram))

        # if flow not active stop on all nodes
        if f_active == 0:
            log("stop on all nodes..{}".format(f_name))
            send("system::all::{}::stop".format(f_name))

        elif f_active == 1:
            # check already started

            first_start = True

            for k, v in pstats.iteritems():

                if k not in m_nodes:
                    continue

                if set(f_ppools).issubset(set([x[1] for x in v])):

                    log("on node {} flow {} is started".format(k, f_name))
                    # send("system::{}::{}::start".format(k, f_name))
                    # if subscribe try again
                    for s in f_subs:
                        send(s)

                    first_start = False

                elif set([x[1] for x in v]).issubset(set(f_ppools)):
                    log("on node {} flow {} is NOT started".format(k, f_name))

                    # force clear
                    send("system::{}::{}::stop".format(k, f_name))

                    first_start = False or first_start

            # need first start

            if first_start:
                log("flow {} first start {}".format(f_name, first_start))

                _ram_need = sum(map(mul, f_ram, f_count))

                # check resources for first start
                # ram cpu

                v = get_load_nodes(p)
                for n, l in v.iteritems():
                    log("load nodes {} {} {}".format(n, l, _ram_need))

                    if l[1] > _ram_need and l[0] < 85:
                        send("system::{}::{}::start".format(n, f_name))
                        break
                    else:
                        continue

            # need start on all avaliable (priority 1)

            if f_priority == 1:
                log("flow {} priority 1 start on all avaliable".format(f_name))

                _ram_need = sum(map(mul, f_ram, f_count))

                # check resources for first start
                # ram cpu

                v = get_load_nodes(p)
                for n, l in v.iteritems():
                    log("load nodes {} {} {}".format(n, l, _ram_need))
                    # if l[1] > _ram_need and l[0] < 85:
                    send("system::{}::{}::start".format(n, f_name))


def get_load_nodes(p):
    con = connect(p)
    cur = con.cursor()

    cur.execute(""" select * from(
                     select s.node, MAX(s.cpu_percent) cpu, (1 - MAX(s.ram_percent)/100) * s.ram_count ram
                         from node_stat s left join (select node, active, MAX(date) from node_list
                                                      where date > DATETIME('NOW', '-15 seconds')
                                                    ) l
                          on s.node = l.node
                         where s.date > DATETIME('NOW', '-15 seconds')
                            and ifnull(l.active, 1) = 1
                         group by s.node
                   ) t
                   order by t.ram desc, t.cpu asc
                """)

    data = {}

    for row in cur:
        data[row[0]] = (row[1], row[2])

    con.close()

    return data


def connect(p):
    return sqlite3.connect(p + '/db/node_collector.db', timeout=3)


def check_add_resourse(p, name, cnt, node, pflows, is_distrib=False):

    log("....check_add_resourse {} {} {} {}".format(name, cnt, node, is_distrib))

    for f in pflows:

        try:

            f_name, f_ppools, f_count, f_ram = f.get("name"),\
                [[y.get("cmd").split("::")[3] for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_pool"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0],\
                [[int(y.get("cmd").split("::")[4]) for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_pool"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0],\
                [[int(y.get("cmd").split("::")[4].split(" ")[1][:-1]) for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_all_workers"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0]

        except Exception as e:
            log("bad flow structure {}: {}".format(f, e))
            continue

        log("....find in conf {} {} {}".format(name, f_name, f_ppools))

        if name in f_ppools:

            v = get_load_nodes(p)
            for n, l in v.iteritems():

                if is_distrib:

                    # if n == node:
                    #     continue

                    _ram_need = sum(map(mul, f_ram, f_count))

                    log("....load nodes {} {} {}".format(n, l, _ram_need))

                    log("....try add all flow {} {} {}".format(n, f_name, _ram_need))

                    if l[1] > _ram_need and l[0] < 85:
                        send("system::{}::change_limit::{}::{}".format(n, f_name, cnt))
                        send("system::{}::{}::start".format(n, f_name))
                        break

                    else:
                        continue

                else:

                    idx = f_ppools.index(name)
                    _ram_need = f_ram[idx] * cnt

                    log("....load node {} {} {}".format(n, l, _ram_need))

                    if l[1] > _ram_need and l[0] < 85:
                        send("system::{}::change_limit::{}::{}".format(node, name, cnt))
                        send("system::{}::{}::start".format(node, name))
                        break

                    else:
                        check_add_resourse(p, name, cnt, node, pflows, True)
                        break


def decrease_ppools(p, pstats, m_nodes, pflows):

    for k, v in pstats.iteritems():

        log("==== start add {} in {} ".format(k, m_nodes))

        if k not in m_nodes:
            continue

        log("..change ppool : {} {}".format(k, v))

        for i in v:
            log("..==check {}".format(i[0]))
            if i[2] > 3:
                i[2] = 3
                log("..too big : {} set {}".format(i[0], i[2]))

            if int(i[1] + i[2]) > 5:
                log("..max 5 proc limit : {}".format(k))
                check_add_resourse(p, i[0], int(i[1] + i[2]), k, pflows, True)

                send("ok")
                continue

            if i[2] > 0:
                check_add_resourse(p, i[0], int(i[1] + i[2]), k, pflows, False)
            else:
                send("system::{}::stop_all_workers::{}::{}".format(k, i[0], int(i[1] + i[2])))
                log("..stop ppool : {} {}".format(k, i[0]))


def start_rebalance_flow(p, m_nodes, pflows):

    for f in pflows:

        try:
            f_name, f_active, f_priority, f_ppools, f_count, f_ram = f.get("name"),\
                f.get("active"), f.get("priority"),\
                [[y.get("cmd").split("::")[3] for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_pool"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0],\
                [[int(y.get("cmd").split("::")[4]) for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_pool"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0],\
                [[int(y.get("cmd").split("::")[4].split(" ")[1][:-1]) for y in x.get("cook")
                  if y.get("cmd").split("::")[2] == "start_all_workers"]
                 for x in f.get("scenes")
                 if x["name"] == f.get("start_scene")][0]

        except Exception as e:
            log("bad flow structure {}: {}".format(f, e))
            continue

        log("read flow {} {} {} {} {}".format(f_name, f_active, f_ppools, f_count, f_ram))

        if f_name.find("_stream") > 0:
            continue

        if f_priority == 1:
            log("flow {} has 1 priority not rebalance ".format(f_name))
            continue

        _from, _to, _other = get_min_stats(p, f_ppools)

        log("...from {}\n to {}\n other {}".format(_from, _to, _other))

        if _from is not None and _to is not None:
            log(".....check criteria...")
            log(".....NODE: {} CPU: {} RAM: {}".format(_to[0], _to[4] + _from[2],
                                                       100 - (_to[5] - _from[3])/_to[7]*100))

            if _from[0] not in m_nodes:
                log("node {} not in active {}".format(_from[0], m_nodes))
                continue

            if _to[4] > 85:
                continue

            if 100 - (_to[5] - _from[3])/_to[7]*100 > 85:
                continue

            log(".....stop on flow {} no node {}".format(f_name, _from[0]))
            send("system::{}::{}::stop".format(_from[0], f_name))

            for x in _other:
                log(".....stop on flow {} no node {}".format(f_name, x[0]))
                send("system::{}::{}::stop".format(x[0], f_name))

            break

        else:
            continue


def get_stats_decrease(p, pflows):
    con = connect(p)
    cur = con.cursor()

    cur.execute("""

        select t.node, t.name, t.cnt,
               t.ok/(60*1000/t.time),
               t.ok, t.nm,
               t.timeo, t.err, t.time, t.run

          from (
             select s.node, l.name
                    ,MAX(ok) ok
                    ,MAX(running) run
                    ,SUM(l.nomore) nm
                    ,MAX(l.error) err
                    ,MAX(l.timeout) timeo
                    ,round(AVG(elapsed)/1000,2) time
                    ,MIN(s.count) cnt

                    from ppool_list l, (select s.node, s.name, MIN(s.count) count
                                              from ppool_stat s
                                               where s.date > DATETIME('NOW', '-60 seconds')
                                              group by s.node, s.name) s

                     where l.node = s.node
                         and l.name = s.name
                         and l.date > DATETIME('NOW', '-60 seconds')
                     group by s.node, s.name

               ) t


               """)

    data = {}
    for row in cur:

        if row[1].find("_stream") > 0:
            continue

        if row[1].find("_async") > 0:

            try:

                _flow = [f for f in pflows if f.get("name") == row[1]][0]
                _atime = [[int(y.get("cmd").split("::")[-1]) for y in x.get("cook") if y.get("cmd").split("::")[2] == "start_all_workers"]
                          for x in _flow.get("scenes")][0][0]

                _diff = (row[2]*_atime*60) - (row[4] + row[9])

                if _diff < 0:
                    workers = 1

                elif _diff > 0 and (_diff-_atime*60)/_atime*60 >= 1:
                    workers = -1

                else:
                    workers = 0

                log("define async flow workers {}".format(workers))

            except Exception:
                log("ERROR define async flow name {}".format(row[1]))
                continue

        else:

            if row[2] is None or row[4] < 0:
                continue

            _oks = 1
            if row[3] is not None:
                _oks = row[3]

            workers = math.ceil(_oks) - math.ceil(row[2])

        log("ppool stat {} need {}".format(row, workers))

        d = [row[1], math.ceil(row[2]), workers]

        # if nomore > 70% when min ppool to 1

        log("check nomore rate {} / {} / {} > 20".format(row[5], row[4], row[2]))
        if row[5] / (row[4] + 1.0) > 0.2:
            log("too many nomore {} add workers:{} ".format(row[1],
                                                            math.ceil(1.0*row[2]*row[5]/(row[4]+1.0))
                                                            ))

            d[2] = math.ceil(1.0*row[2]*row[5]/(row[4]+1.0))

        # if err > 70% when min ppool to 1

        log("check err rate {} / {} > 70".format(row[7], row[4]))
        if row[7] / (row[4] + 1.0) > 0.7:
            log("too many err {}: {} > 70% ".format(row[1],
                                                    row[7]/(row[4] + 1.0)))
            d[2] = -1 * math.ceil(row[2]) + 1

        # no change
        if d[2] == 0:
            continue

        if d[2] < 0 and row[5] / (row[4] + 1.0) > 0.05:  # stay while nomore exists
            continue

        if data.get(row[0]) is None:
            data[row[0]] = [d]
        else:
            data.get(row[0]).append(d)

    con.close()

    return data


def get_min_stats(p, names):
    con = connect(p)
    cur = con.cursor()

    log("...start rebalance flow {}".format(names))

    cur.execute("""

        select node, count(name), SUM(pcpu), SUM(pram), ncpu, nram, cpu_count, ram_count, ram_percent,
                rnd, okl
                from (
        select s.node, s.name
               ,AVG(s.cpu_percent) pcpu, AVG(s.ram_percent)*ns.ram_count/100 pram
               ,AVG(ns.cpu_percent) ncpu, (100 - AVG(ns.ram_percent))*ns.ram_count/100 nram
               ,ns.cpu_count, ns.ram_count, ns.ram_percent, ROUND(ns.cpu_count/10) as rnd
               ,MAX(l.ok) okl

             from ppool_list l, ppool_stat s,
                  node_stat ns
             where l.node = s.node
                 and l.name = s.name
                 and s.node = ns.node
                 and l.date > DATETIME('NOW', '-15 seconds')
                 and l.name in ({})
             group by s.node, s.name
              --  HAVING MAX(s.count) = 1
        ) group by node
        order by rnd desc, nram asc

               """.format(','.join(['?']*len(names))), names)

    data = [None, None, []]
    for row in cur:

        if row[1] != len(names):
            continue

        if row[10] is not None and row[10] > 0:
            continue

        if data[0] is None:
            data[0] = row
        else:
            if data[1] is None:
                data[1] = row
            else:
                data[2].append(row)

    con.close()

    return data[0], data[1], data[2]
