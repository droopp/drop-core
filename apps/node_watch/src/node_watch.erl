-module(node_watch).
-behaviour(gen_server).

%% API.
-export([start_link/0]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-export([node_mcast_stream/1]).
-export([node_mcast_api/1]).
-export([cast_nodes/1]).

-record(state, {
          nodes=[]
}).

-include("node_watch.hrl").

%% API.

-spec start_link() -> {ok, pid()}.
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


cast_nodes(Msg) ->
    %% ?Debug(Msg),
    gen_server:cast(?MODULE, {cast_nodes, Msg}).


%% gen_server.

init([]) ->

    pg2:create(?MODULE),
     pg2:join(?MODULE, self()),

    net_kernel:monitor_nodes(true, [nodedown_reason]),

    erlang:send_after(?TIMEOUT, self(), ping_nodes),
     erlang:send_after(?TIMEOUT, self(), ping_world),

	{ok, #state{nodes=[node()]}}.


handle_call(_Request, _From, State) ->
	{reply, ignored, State}.



handle_cast({cast_nodes, Msg}, State) ->

    ?Debug3({node_watch_nodes, Msg}),

     Nodes = [erlang:list_to_atom(erlang:binary_to_list(X))||
              X<-binary:split(Msg, <<",">>, [global])],

      ?Debug3({register_nodes, Nodes}),
	    {noreply, State#state{nodes=Nodes}};


handle_cast(_Msg, State) ->
    ?Debug3({_Msg}),
	{noreply, State}.



handle_info(ping_nodes, #state{nodes=N}=State) ->

    %% error_logger:info_msg("pinging nodes ~p~n",[net_adm:host_file()]),
       lists:foreach(fun(X) ->
                             net_adm:ping(X)
                     end,
                    N),

    %% disconnect no list nodes
    %%

    D = fun(I, L) -> lists:all(fun(X) -> X=/=I end, L) end,
      Down = [X||X<-nodes(), D(X, N)],

       ?Debug3({disconnect_nodes, N, nodes(), Down}),
       lists:foreach(fun(X) ->
                             erlang:disconnect_node(X)
                     end,
                     Down),

    erlang:send_after(?TIMEOUT, self(), ping_nodes),

	{noreply, State};



handle_info(ping_world, State) ->

     Msg=erlang:list_to_bitstring(["system0::node_world::", 
                                    erlang:atom_to_list(node()), "::", 
                                    os:getenv("HOSTNAME0"), "\n"
                                  ]),

        node_scheduler:call(node(),
                            fun(N, C) -> 
                                    ppool_worker:cast_worker(N, C)
                            end,
                            node_mcast_api,
                            Msg
                           ),

            erlang:send_after(?TIMEOUT, self(), ping_world),

	{noreply, State};



handle_info({nodedown, Node, InfoList}, State)->

    error_logger:error_msg("node ~p is down: ~p~n",[Node, InfoList]),

    [{nodedown_reason,I}] = InfoList,

        Msg=erlang:list_to_bitstring(["system::node_watch::", 
                                       erlang:atom_to_list(Node), "::", 
                                       "nodedown::", 
                                       erlang:atom_to_list(I), "\n"]),

        node_scheduler:call(node(),
                            fun(N, C) -> 
                                    ppool_worker:call_worker(N, C)
                            end,
                            node_collector,
                            Msg
                           ),

	{noreply, State};


handle_info({nodeup, Node, _InfoList}, State) ->

    error_logger:warning_msg("node ~p is up~n",[Node]),


        Msg=erlang:list_to_bitstring(["system::node_watch::", 
                                       erlang:atom_to_list(Node), "::", 
                                       "nodeup::", 
                                       "nodeup..", "\n"]),

        node_scheduler:call(node(),
                            fun(N, C) -> 
                                    ppool_worker:call_worker(N, C)
                            end,
                            node_collector,
                            Msg
                           ),

    {noreply, State};


handle_info(Info, State) ->
    error_logger:info_msg("unknow msg ~p~n",[Info]),

	{noreply, State}.




terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.



%%
%%
%% mcast stream worker 
%%  
%%

receiver(F) ->
   receive
       {udp, _Socket, _IP, _InPortNo, Packet} ->
           ?Debug2({_IP, _InPortNo, Packet}),

            F!{self(), {data, [Packet]}},
 
           receiver(F);
       _Any -> 
            ?Debug2({mcast_recv, _Any}),
           receiver(F)

   after 10000 ->
         F!{self(), {data, [<<"ok">>]}},
           receiver(F)
   end.


node_mcast0(F) ->

  %% catch multicast msg
  %%
  
  S=open(?ADDR, ?PORT),
   gen_udp:controlling_process(S, self()),
    receiver(F).
   

node_mcast_stream(F) ->
    receive
        _ -> 
         F!{self(), {data, [<<"ok">>]}},

          ?Debug2({node_mcast0, F}), 
            node_mcast0(F)
    end.



open(Addr,Port) ->
   {ok,S} = gen_udp:open(Port,[{reuseaddr,true},
                               {ip,Addr},
                               {multicast_ttl,4},
                               {multicast_loop,false}, binary]),

   inet:setopts(S,[{add_membership,{Addr,{0,0,0,0}}}]),

   S.




%%
%%
%% mcast API worker 
%%  
%%


node_mcast_api0(Msg) ->

  %% send multicast msg
  %%
  
    {ok, S} = gen_udp:open(?PORT,
                           [binary,
                            {active, false},
                            {reuseaddr, true},
                            {ip, ?ADDR},
                            {add_membership, {?ADDR, {0,0,0,0}}}
                           ]),

            gen_udp:send(S, ?ADDR, ?PORT, Msg),
            gen_udp:close(S).


node_mcast_api(F) ->
    receive
        Msg -> 

          ?Debug2({node_mcast_api0, F, body_to_msg(Msg)}), 
            node_mcast_api0(body_to_msg(Msg)),
              F!{self(), {data, [<<"ok">>]}},

               node_mcast_api(F)

    end.


body_to_msg(Body) ->
    case binary:last(Body) =:= 10 of
        true ->
            binary:part(Body, {0, byte_size(Body)-1});

        false ->
            Body

    end.


