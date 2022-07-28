-module(drop_api_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

-include("api_handler.hrl").


start(_Type, _Args) ->
    Dispatch = cowboy_router:compile([
                      {'_', [
                          {"/api/v1/[:flow]", api_handler, []}
                      ]}
    ]),

	{ok, _} = cowboy:start_clear(http, 
                                 [{port, list_to_integer(os:getenv("DROP_API_PORT", ?PORT))}]
                                 ,#{env => #{dispatch => Dispatch}
                                 ,idle_timeout => ?IDLE_TIMEOUT
	}),

	drop_api_sup:start_link().


stop(_State) ->
	ok.
