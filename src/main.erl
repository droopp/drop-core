-module(main).
-export([
         start/0,
         stop/0
        ]).

start() ->

    application:start(ppool).

stop() ->

     application:stop(ppool).


