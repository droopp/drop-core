-module(node_watch_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
	node_watch_sup:start_link().

stop(_State) ->
	ok.
