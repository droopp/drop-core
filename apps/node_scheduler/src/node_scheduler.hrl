
-define(NODE_API_WORKERS, 10).
-define(NODE_API_TIMEOUT, 5000).

-define(NODE_INFO_WORKERS, 1).
-define(NODE_INFO_INTERVAL, 5).
-define(NODE_INFO_TIMEOUT, 10000).

-define(NODE_CLTR_WORKERS, 1).
-define(NODE_CLTR_TIMEOUT, 10000).
-define(NODE_CLTR_FLUSH_CNT, 1000).
-define(NODE_CLTR_FLUSH_TIME, 5).

-define(NODE_INFO_IN_WORKERS, 1).
-define(NODE_INFO_IN_TIMEOUT, 10000).
-define(NODE_INFO_IN_TICK, 5000).

-define(FLOWER_WORKERS, 1).
-define(FLOWER_TIMEOUT, 10000).

-define(FLOWER_SC_WORKERS, 1).
-define(FLOWER_SC_TIMEOUT, 30000).
-define(FLOWER_SC_INTERVAL, 3).

-define(NODE_MCAST_WORKERS, 1).
-define(NODE_MCAST_TIMEOUT, 60000).

-define(NODE_MCAST_API_WORKERS, 1).
-define(NODE_MCAST_API_TIMEOUT, 10000).

-define(RUNC, "docker run --rm --log-driver none -i -u drop -w /home/drop/").
