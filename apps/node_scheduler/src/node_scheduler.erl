-module(node_scheduler).
-behaviour(gen_server).

%% API.
-export([start_link/0,
         call/4,
         cmd/2,
         cmd/3,
         api/1,
         node_info_internal_stream/1,
         try_start/1,
         restart/0
        ]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
}).


-include_lib("stdlib/include/ms_transform.hrl").

-include("node_scheduler.hrl").
-include("../../src/ppool.hrl").
-include("../../apps/drop_api/src/api_handler.hrl").


%% API.
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


%% gen_server.

init([]) ->
	{ok, #state{}, 0}.

restart() ->
    gen_server:call(?MODULE, restart).


handle_call(restart, _From, State) ->

    ppool:stop_pool(ppool, node_info_stream),
    ppool:stop_pool(ppool, node_info_internal_stream),
    ppool:stop_pool(ppool, node_collector),
    ppool:stop_pool(ppool, node_api),
    ppool:stop_pool(ppool, flower),
    ppool:stop_pool(ppool, flower_sc_stream),
    ppool:stop_pool(ppool, node_mcast_stream),
    ppool:stop_pool(ppool, node_mcast_api),

	{reply, ok, State, 0};

handle_call(_Request, _From, State) ->
	{reply, ignored, State}.


handle_cast(_Msg, State) ->
	{noreply, State}.


handle_info(timeout, State) ->

    %% Systems pools

    ppool:start_pool(ppool, {node_info_stream, ?NODE_INFO_WORKERS, 
                            {port_worker, start_link, []} }),

    ppool:start_pool(ppool, {node_collector, ?NODE_CLTR_WORKERS, 
                            {port_worker, start_link, []} }),

    ppool:start_pool(ppool, {node_api, ?NODE_API_WORKERS, 
                            {worker, start_link, []} }),

    ppool:start_pool(ppool, {node_info_internal_stream, ?NODE_INFO_IN_WORKERS, 
                            {worker, start_link, []} }),

    ppool:start_pool(ppool, {flower, ?FLOWER_WORKERS, 
                            {port_worker, start_link, []} }),

    ppool:start_pool(ppool, {flower_sc_stream, ?FLOWER_SC_WORKERS, 
                            {port_worker, start_link, []} }),

    ppool:start_pool(ppool, {node_mcast_stream, ?NODE_MCAST_WORKERS, 
                            {worker, start_link, []} }),

    ppool:start_pool(ppool, {node_mcast_api, ?NODE_MCAST_API_WORKERS, 
                            {worker, start_link, []} }),

    %% link ppools
    
    %% node and processes stats
    ppool_worker:subscribe(node_info_stream, {node_collector, <<"no">>, dall}),

    %% processes cnt err timeout elapsed 
    ppool_worker:subscribe(node_info_internal_stream, {node_collector, <<"no">>, dall}),
    
    %% system0 echo from all nodes in cluster
    ppool_worker:subscribe(node_mcast_stream, {node_collector, <<"system0::">>, one}),

    %% api calls thru executor (flower)
    ppool_worker:subscribe(flower, {node_api, <<"system::">>, one}),

    %% scheduler calls
    %% system - to pools
    %% system0 - to other nodes
    ppool_worker:subscribe(flower_sc_stream, {flower, <<"system::">>, one}),

    ppool_worker:subscribe(flower_sc_stream, {node_mcast_api, <<"system0::">>, one}),


    %% system info stream worker

    {ok, full_limit}=ppool_worker:start_all_workers(node_info_stream,
                             {cmd(lists:concat(["node_info_stream/node_info_stream",
                                    " --node ", node(),                      %% current node
                                    " --interval ", ?NODE_INFO_INTERVAL,     %% interval in ms  
                                    " --drop ", "node_info_stream"]),   %% marker to collect stats
                                   "node_info_stream.log"                    %% log file name
                                  ), ?NODE_INFO_TIMEOUT}                     %% process timeout
    ),

    %% collect node info from cluster

    {ok, full_limit}=ppool_worker:start_all_workers(node_collector,
                             {cmd(lists:concat(["node_collector/node_collector",
                                    " --db ", os:getenv("DROP_VAR_DIR") ,"/db",  %% db file location
                                    " --flush-count ", ?NODE_CLTR_FLUSH_CNT,     %% in memory cnt to flush to db
                                    " --flush-time ", ?NODE_CLTR_FLUSH_TIME,     %% after ms to flush to db
                                    " --drop ", "node_collector"]),         %% marker to collect stats
                                   "node_collector.log"                          %% log file name
                                  ), ?NODE_CLTR_TIMEOUT}                         %% process timeout
    ),


    %% flower

    {ok, full_limit}=ppool_worker:start_all_workers(flower, 
                              {cmd(lists:concat(["flower/flower",
                                   " --flower-dir ", os:getenv("DROP_VAR_DIR") ,"/flows", %% flows dir with YAML files
                                   " --drop ", "flower"]),                           %% marker to collect stats
                                   "flower.log"
                                  ), ?FLOWER_TIMEOUT}
    ),

    %% scheduler

    {ok, full_limit}=ppool_worker:start_all_workers(flower_sc_stream,         
                              {cmd(lists:concat(["flower_sc_stream/flower_sc_stream",
                                    " --var-dir ", os:getenv("DROP_VAR_DIR"),          %% var dir with /db and /flows
                                    " --node ", node(),                                %% current node
                                    " --interval ", ?FLOWER_SC_INTERVAL,               %% scheduler interval
                                    " --vip ", os:getenv("DROP_VIP"),                  %% VIP ip addr
                                    " --vip-iface ", os:getenv("DROP_VIP_IFACE"),       %% VIP net iface
                                    " --drop ", "flower_sc_stream"]),             %% marker to collect stats
                                    "flower_sc_stream.log"
                                    ), ?FLOWER_SC_TIMEOUT}
    ),

    %% api

    {ok, full_limit}=ppool_worker:start_all_workers(node_api, 
                                    {{node_scheduler, api}, ?NODE_API_TIMEOUT}
    ),

    %% collect metric about actors

    {ok, full_limit}=ppool_worker:start_all_workers(node_info_internal_stream, 
                              {{node_scheduler, node_info_internal_stream}, ?NODE_INFO_IN_TIMEOUT}
    ),

    %% multicast zeroconf

    {ok, full_limit}=ppool_worker:start_all_workers(node_mcast_stream, 
                              {{node_watch, node_mcast_stream}, ?NODE_MCAST_TIMEOUT}
    ),

    {ok, full_limit}=ppool_worker:start_all_workers(node_mcast_api, 
                              {{node_watch, node_mcast_api}, ?NODE_MCAST_API_TIMEOUT}
    ),



	  {noreply, State};



handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.



cmd(Img, Cmd, Log) ->

    R = case string:find(Img, "plugin") of
       nomatch ->
            lists:concat([?RUNC,
                              " ",  Img, " ", Cmd,
                              " 2>>", os:getenv("DROP_LOG_DIR"), "/", Log]);
        _ ->
            lists:concat([os:getenv("DROP_VAR_DIR"),"/plugins/", Cmd,
                            " 2>>", os:getenv("DROP_LOG_DIR"), "/", Log])
 
    end,

     ?Trace({cmd, R}),
      R.


cmd(Cmd, Log) ->

   R = lists:concat([os:getenv("DROP_HOME"),"/priv/", Cmd, 
                     " 2>>", os:getenv("DROP_LOG_DIR"), "/", Log]),

    ?Trace({cmd, R}),

   R.


try_start(N) ->
     case N() of
          {ok, []} -> 
             timer:sleep(1000),
             try_start(N);

        _ -> ok

     end.



call(Type, F, Name, Cmd) ->

    ?Trace({?MODULE, Type, F, Name, Cmd}),

    Tf = fun(P0, Cmd0) ->
            try F(P0, Cmd0) of
                _ -> ok
            catch 
                _:_ -> 
                     error_logger:warning_msg("call api ~p~n ",
                                              [Cmd]),
                      ok
            end
        end,

    Get_memb = fun(N0, F0) ->
                      try F0(N0) of
                          {error,{no_such_group,N0}} ->
                             [];

                            R -> R
                      catch 
                         _:_ ->

                           error_logger:warning_msg("get members api ~p~n ",
                                              [N0]),
                            []
            end
        end,


    Res = case Type of

        local ->
            [Tf(P, Cmd)||P <- [X || X<- Get_memb(Name, fun pg:get_local_members/1), 
                                                   node(X)=:=node()]];
        all ->
            [Tf(P, Cmd)||P <- [X || X<- Get_memb(Name, fun pg:get_members/1)]];
 
        Node ->
            [Tf(P, Cmd)||P <- [X || X <- Get_memb(Name, fun pg:get_members/1), node(X)=:=Node]]
 
    end,

    Res.


%%
%%
%% INFO stream worker 
%% tick every X secs
%%  
%%

average([]) ->
    0;

average(X) ->
        lists:sum(X) / length(X).



get_worker_info(N) ->


  R=ets:select(N,
                ets:fun2ms(fun(X)
                                -> X 
                            end)
              ),
  
   Err=length([X||X <- R, X#worker_stat.status =:=error]),
    Touts=length([X||X <- R, X#worker_stat.status =:=timeout]),
      Run=length([X||X <- R, X#worker_stat.status =:=running]),
       Cnt=length([X||X <- R, X#worker_stat.status =:=ok]),
 
      Elaps=average([timer:now_diff(X#worker_stat.time_end, 
                                    X#worker_stat.time_start)
                     ||X <- R, X#worker_stat.time_end=/=undefined]),

       ["system::", 
        atom_to_list(node()), "::",
        atom_to_list(N), "::",
        integer_to_list(Err), "::",
        integer_to_list(Touts), "::",
        integer_to_list(Run), "::",
        integer_to_list(Cnt), "::",
        lists:flatten(io_lib:format("~p", [Elaps]))
       ].



node_info_loop(F) ->

  %% ppools error & timeout
  ?Trace({start_node_in_worker, F}), 
  
  List=[X||X<-pg:which_groups(), 
            lists:suffix("_ev", atom_to_list(X))=/=true,
            X=/=ppool
       ],

   lists:foreach(fun(M)->

                      try get_worker_info(M) of
                        Msg -> 
                            Msg2=list_to_binary(Msg),
                                F!{self(), {data, [Msg2]}}
 
                      catch
                        _:_ -> ok
                      end  
                end,
                 List

   ),

    timer:sleep(?NODE_INFO_IN_TICK),
      node_info_loop(F).


node_info_internal_stream(F) ->
          ?Trace({start_node_in_worker, F}), 
            node_info_loop(F).

%%
%%
%%
%% API worker
%%
%%

call_api(Msg) ->

           ?Trace({recv, Msg}),

            R = binary:replace(Msg, <<"\n">>, <<>>),

            [_|[Tp|[Fn|[Name|A]]]] = binary:split(R, <<"::">>, [global]),

           ?Trace({Tp, Fn, Name, A}),

           Ret = case erlang:binary_to_atom(Fn, latin1) of

               cast_nodes ->

                   [Args|_] = A,
                        node_watch:cast_nodes(Args);

               start_pool ->

                   [Cnt|_] = A,

                    _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, {Nm, C}) -> 
                                    ppool:start_pool(N, 
                                                     {Nm, C, 
                                                      {port_worker, start_link, []}
                                                     }
                                                    ) end,

                            ppool, 
                            {erlang:binary_to_atom(Name, latin1),
                             erlang:binary_to_integer(Cnt)}
                              );

               start_sys_pool ->

                   [Cnt|_] = A,

                    _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, {Nm, C}) -> 
                                    ppool:start_pool(N, 
                                                     {Nm, C, 
                                                      {worker, start_link, []}
                                                     }
                                                    ) end,

                            ppool, 
                            {erlang:binary_to_atom(Name, latin1),
                             erlang:binary_to_integer(Cnt)}
                              );

               stop_pool ->
                   
                    _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> ppool:stop_pool(N, C) end,
                            ppool,
                            erlang:binary_to_atom(Name, latin1)
                             );

               start_worker ->

                   [Img, Cmd, Log, Tm] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, {I, C, L, T}) -> ppool_worker:start_worker(N, 
                                             {cmd(I, C, L), T})
 
                            end,
                            erlang:binary_to_atom(Name, latin1),
                            {
                             erlang:binary_to_list(Img),
                             erlang:binary_to_list(Cmd),
                             erlang:binary_to_list(Log),
                             erlang:binary_to_integer(Tm)
                            }
                             );


               stop_worker ->


                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, _C) -> ppool_worker:cast_worker(N, 
                                                    stop)
 
                            end,
                            erlang:binary_to_atom(Name, latin1),
                            false
                             );

               stop_all_workers ->

                   [Cnt|_] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> 
                                     ppool_worker:stop_all_workers(N, C)

                            end,

                            erlang:binary_to_atom(Name, latin1),
                            erlang:binary_to_integer(Cnt)
                             );


               start_all_workers ->

                   [Img, Cmd, Log, Tm] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, {I, C, L, T}) -> 
                                    ppool_worker:start_all_workers(N, 
                                                                   {cmd(I, C, L), 
                                                                    T})
                            end,
                            erlang:binary_to_atom(Name, latin1),
                            {
                             erlang:binary_to_list(Img),
                             erlang:binary_to_list(Cmd),
                             erlang:binary_to_list(Log),
                             erlang:binary_to_integer(Tm)
                            }
                             );


               start_sys_workers ->

                   [Mod, Fun, Tm] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, {M, F, T}) -> 
                                    ppool_worker:start_all_workers(N, 
                                                                   {{M, F}, 
                                                                    T})
                            end,
                            erlang:binary_to_atom(Name, latin1),
                            {
                             erlang:binary_to_atom(Mod, latin1),
                             erlang:binary_to_atom(Fun, latin1),
                             erlang:binary_to_integer(Tm)
                            }
                             );

               call_worker ->

                   [Args|_] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> 
                                     ppool_worker:call_worker(N, C)

                            end,

                            erlang:binary_to_atom(Name, latin1),
                            <<Args/binary, <<"\n">>/binary>>
                             );

               cast_worker ->

                   [Args|_] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> 
                                    ppool_worker:cast_worker(N, C)
 
                            end,
                            erlang:binary_to_atom(Name, latin1),
                            <<Args/binary, <<"\n">>/binary>>
                             );


               first_call_worker ->

                   [Args|_] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> 
                                    ppool_worker:first_call_worker(N, C)
 
                            end,
                            erlang:binary_to_atom(Name, latin1),
                            <<Args/binary, <<"\n">>/binary>>
                             );

               cast_all_workers ->

                   [Args|_] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> 
                                    ppool_worker:cast_all_workers(N, C)
 
                            end,
                            erlang:binary_to_atom(Name, latin1),
                             <<Args/binary, <<"\n">>/binary>>
                             );


               subscribe ->

                   [To, Fl, Api] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> 
                                    ppool_worker:subscribe(N, C)
 
                            end,
                            erlang:binary_to_atom(Name, latin1),
                             {erlang:binary_to_atom(To, latin1),
                              Fl,
                              erlang:binary_to_atom(Api, latin1)
                              }
                             );


               unsubscribe ->

                   [To] = A,

                   _Res = call(erlang:binary_to_atom(Tp, latin1),
                            fun(N, C) -> 
                                    ppool_worker:unsubscribe(N, C)
 
                            end,
                            erlang:binary_to_atom(Name, latin1),
                             {erlang:binary_to_atom(To, latin1)
                             }
                             );

               _M ->
                 ?Trace({unknow_call_api, _M}),
                 ok
           end,

           Ret.


api(F) ->
    receive

         Msg ->

            Msgs = binary:split(Msg, ?SPLIT_MSG_SEQ, [global]),
             ?Trace({recv, Msgs}),

              lists:foreach(fun(M) -> call_api(M) end,  Msgs),

                F!{self(), {data, [<<"ok">>]}},

             api(F)

    end.
