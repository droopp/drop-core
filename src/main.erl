-module(main).
-export([
         start/0,
         stop/0
        ]).

start() ->

    ok=application:start(drop),
       ok.

stop() ->

     ok=application:stop(drop),
       ok.


