
ppool:start_pool(ppool, {python_async, 1,{port_worker, start_link, []} }).
ppool_worker:start_worker(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>/tmp/async.1", 10000}).
ppool_worker:cast_worker_defer(python_async, <<"cast_worker_defer\n">>).
ppool_worker:cast_worker(python_async, <<"cast_worker\n">>).
ppool_worker:cast_all_workers(python_async, <<"cast_all_workers\n">>).
ppool_worker:call_worker(python_async, <<"call_worker\n">>).
ppool_worker:call_cast_worker(python_async, no, <<"call_cast_worker\n">>).
ppool_worker:dacast_worker(python_async, no, <<"dacast_worker\n">>).

erlang:process_info(whereis(python_async)).


ppool:start_pool(ppool, {python, 1,{port_worker, start_link, []} }).
ppool_worker:start_worker(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>/tmp/async.1", 10000}).
ppool_worker:cast_worker_defer(python, <<"cast_worker_defer\n">>).
ppool_worker:cast_worker(python, <<"cast_worker\n">>).
ppool_worker:cast_all_workers(python, <<"cast_all_workers\n">>).
ppool_worker:call_worker(python, <<"call_worker\n">>).
ppool_worker:call_cast_worker(python, no, <<"call_cast_worker\n">>).
ppool_worker:dacast_worker(python, no, <<"dacast_worker\n">>).

erlang:process_info(whereis(python)).

ppool:start_pool(ppool, {python_stream, 1,{port_worker, start_link, []} }).
ppool_worker:start_worker(python_stream, {"python /opt/drop-core/examples/python_example/example_stream.py 1 2>/tmp/async.1", 10000}).
ppool_worker:cast_worker_defer(python_stream, <<"cast_worker_defer\n">>).
ppool_worker:cast_worker(python_stream, <<"cast_worker\n">>).
ppool_worker:cast_all_workers(python_stream, <<"cast_all_workers\n">>).
ppool_worker:call_worker(python_stream, <<"call_worker\n">>).
ppool_worker:call_cast_worker(python_stream, no, <<"call_cast_worker\n">>).
ppool_worker:dacast_worker(python_stream, no, <<"dacast_worker\n">>).

erlang:process_info(whereis(python_stream)).


%%%%%%%%%%%%%%%%


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>/tmp/async.1", 10000}).
ppool_worker:cast_worker_defer(python_async, <<"cast_worker_defer\n">>).
ppool_worker:cast_worker(python_async, <<"cast_worker\n">>).
ppool_worker:cast_all_workers(python_async, <<"cast_all_workers\n">>).
ppool_worker:call_worker(python_async, <<"call_worker\n">>).
ppool_worker:call_cast_worker(python_async, no, <<"call_cast_worker\n">>).
ppool_worker:dacast_worker(python_async, no, <<"dacast_worker\n">>).

[ppool_worker:cast_worker_defer(python_async, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].
[ppool_worker:cast_worker(python_async, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>/tmp/async.1", 10000}).
ppool_worker:cast_worker_defer(python, <<"cast_worker_defer\n">>).
ppool_worker:cast_worker(python, <<"cast_worker\n">>).
ppool_worker:cast_all_workers(python, <<"cast_all_workers\n">>).
ppool_worker:call_worker(python, <<"call_worker\n">>).
ppool_worker:call_cast_worker(python, no, <<"call_cast_worker\n">>).
ppool_worker:dacast_worker(python, no, <<"dacast_worker\n">>).

[ppool_worker:cast_worker_defer(python, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].
[ppool_worker:cast_worker(python, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].

%%%%%%%%%%%%%%%%


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python, {python_async, <<"no">>, sone}),
[ppool_worker:cast_worker(python, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python, {python_async, <<"no">>, one}),
[ppool_worker:cast_worker(python, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python, {python_async, <<"no">>, all}),
[ppool_worker:cast_worker(python, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python, {python_async, <<"no">>, done}),
[ppool_worker:cast_worker(python, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python, {python_async, <<"no">>, dall}),
[ppool_worker:cast_worker(python, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


%%%%%%%%%%%%%%%%


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python_async, {python, <<"no">>, sone}),
[ppool_worker:cast_worker(python_async, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python_async, {python, <<"no">>, one}),
[ppool_worker:cast_worker(python_async, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python_async, {python, <<"no">>, all}),
[ppool_worker:cast_worker(python_async, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python_async, {python, <<"no">>, done}),
[ppool_worker:cast_worker(python_async, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].


ppool:start_pool(ppool, {python_async, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python_async, {"python /opt/drop-core/examples/python_example/example_async.py 100 2>>/tmp/async.1", 10000}).
ppool:start_pool(ppool, {python, 2,{port_worker, start_link, []} }).
ppool_worker:start_all_workers(python, {"python /opt/drop-core/examples/python_example/example.py 100 2>>/tmp/async.2", 10000}).
ppool_worker:subscribe(python_async, {python, <<"no">>, dall}),
[ppool_worker:cast_worker(python_async, <<"call_worker\n">>)||X<-[1,2,3,4,5,6,7,8,9,10]].





