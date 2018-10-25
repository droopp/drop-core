

-module(main).
-export([
         start/0,
         stop/0
        ]).


start() ->

    %% http api
    application:start(crypto),
    application:start(asn1),
    application:start(public_key),
    application:start(ssl),

    application:start(cowlib),
    application:start(ranch),
    application:start(cowboy),
    application:start(drop_api),

    application:start(ppool),
    application:start(node_scheduler),
    application:start(node_watch),
 
       ok.

stop() ->

     application:stop(node_watch),
     application:stop(node_scheduler),
     application:stop(ppool),

     %% http api
     application:stop(drop_api),
     application:stop(cowboy),
     application:stop(ranch),
     application:stop(cowlib),

     application:stop(ssl),
     application:stop(public_key),
     application:stop(asn1),
     application:stop(crypto),

       ok.


