-module(ppool).
-behaviour(gen_server).

%% API.
-export([start_link/0]).
-export([start_pool/2, stop_pool/2]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
}).

%% API.

-spec start_link() -> {ok, pid()}.
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% gen_server.

init([]) ->

    pg:create(?MODULE),
     pg:join(?MODULE, self()),

	{ok, #state{}}.


start_pool(N, {Name, Limit, {M, F, _}}) ->
    gen_server:call(N, {start_pool, {Name, Limit, {M, F, [Name]}} }).


stop_pool(N, Name) ->
    gen_server:call(N, {stop_pool, Name}).



handle_call({start_pool, {Name, Limit, MFA}}, _From, State) ->
    P = ppool_sup:start_pool(Name, Limit, MFA),

	{reply, P, State};


handle_call({stop_pool, Name}, _From, State) ->

     P = ppool_sup:stop_pool(Name),

      case pg:get_members(Name) of

          [] ->
                pg:delete(Name),
                pg:delete(list_to_atom(atom_to_list(Name)++"_ev"));

           _ -> ok

      end,

	  {reply, P, State};


handle_call(_Request, _From, State) ->
	{reply, ignored, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.
