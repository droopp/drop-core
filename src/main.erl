-module(main).
-export([
         start/0,
         stop/0
        ]).


start() ->

    %% http api
    ok=application:start(crypto),
    ok=application:start(asn1),
    ok=application:start(public_key),
    ok=application:start(ssl),

    ok=application:start(cowlib),
    ok=application:start(ranch),
    ok=application:start(cowboy),
    ok=application:start(drop_api),

    %% process pool
    ok=application:start(ppool),
 
    ok=application:start(node_scheduler),
    ok=application:start(node_watch),
 
       ok.

stop() ->

     ok=application:stop(node_watch),
     ok=application:stop(node_scheduler),

     %% process pool
     ok=application:stop(ppool),

     %% http api
     ok=application:stop(drop_api),
     ok=application:stop(cowboy),
     ok=application:stop(ranch),
     ok=application:stop(cowlib),

     ok=application:stop(ssl),
     ok=application:stop(public_key),
     ok=application:stop(asn1),
     ok=application:stop(crypto),

       ok.


