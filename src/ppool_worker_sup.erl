-module(ppool_worker_sup).
-behaviour(supervisor).

-export([start_link/2]).
-export([init/1]).

start_link(Name, MFA) ->
	supervisor:start_link({local, 
                           list_to_atom(atom_to_list(Name)++"_sup")},
                          ?MODULE, [MFA]).

init([MFA]) ->
   {M,F,A} = MFA,
    Proc = [{ppool_worker,
             {M,F,A},
             transient,
             brutal_kill,
             worker,
             [M]
     }],

	{ok, {{simple_one_for_one, 100, 1}, Proc}}.
