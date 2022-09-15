-module(node_watch_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Procs = [{node_watch,
              {node_watch, start_link, []},
              permanent,
              brutal_kill,
              worker,
             [node_watch]
            }],
            
	{ok, {{one_for_one, 100, 1}, Procs}}.
