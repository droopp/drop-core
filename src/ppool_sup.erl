-module(ppool_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).
-export([start_pool/3, stop_pool/1]).


start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    Procs = [{ppool,
              {ppool, start_link, []},
              permanent,
              brutal_kill,
              worker,
             [ppool]
     }],

	{ok, {{one_for_one, 100, 1}, Procs}}.


start_pool(Name, Limit, MFA) ->
    Child = {Name,
             {ppool_master_worker_sup, start_link, [Name, Limit, MFA]},
             permanent,
             10000,
             supervisor,
             [ppool_master_worker_sup]
     },

    supervisor:start_child(?MODULE, Child).


stop_pool(Name) ->
    supervisor:terminate_child(?MODULE, Name),
    supervisor:delete_child(?MODULE, Name).


