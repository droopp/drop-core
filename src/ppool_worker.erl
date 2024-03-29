-module(ppool_worker).
-behaviour(gen_server).

%% API.
-export([start_link/3,

         start_worker/2,
         start_worker/3,

         register_worker/2,
         unregister_worker/2,

         start_all_workers/2,
         start_all_workers/3,
         stop_all_workers/1,
         stop_all_workers/2,

         cap_workers/3,

         call_worker/2,
         call_worker/3,
         first_call_worker/2,

         cast_worker/2,
         cast_worker/3,
         dcast_worker/3,
         dacast_worker/3,
         cast_worker_defer/2,

         cast_all_workers/2,
         cast_all_workers/3,

         set_status_worker/3,
         get_result_worker/2,
         add_nomore_info/1,

         subscribe/2,
         unsubscribe/2

        ]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).


-include("ppool.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(INTERVAL, 5000).
-define(INTERVAL_NOMORE, 5000).

-record(state, {
          limit, 
          mfa, 
          name,
          workers_pids=maps:new(),
          ports_pids=maps:new(),
          nomore=0,
          async,
          stream
}).


%% init

start_link(Name, Limit, MFA) ->
	gen_server:start_link({local, Name}, ?MODULE, [Name, Limit, MFA], []).


init([Name, Limit, MFA]) ->
    Name = ets:new(Name, [set, public, named_table, 
                          {keypos, #worker_stat.ref},
                          {read_concurrency, true},
                          {write_concurrency, true}
                         ]),

    pg:join(Name, self()),

     erlang:send_after(?INTERVAL, self(), clean_ets),
     erlang:send_after(?INTERVAL_NOMORE, self(), send_nomore),

	  Async = string:find(erlang:atom_to_list(Name), "_async") =/= nomatch,
	  Stream = string:find(erlang:atom_to_list(Name), "_stream") =/= nomatch,

        case Async of
          true -> process_flag(trap_exit, true);
          _ -> ok
        end,
           
    	?Trace({init, async, Async}),

	{ok, #state{limit=Limit, mfa=MFA, name=Name, async=Async, stream=Stream}}.



register_worker(Name, Pid0) ->
   
   ?Trace({register, Pid0}),

    case Pid0 of
       {Pid, Port} ->
          gen_server:call(Name, {register, {Pid, Port}});

       Pid -> 
          gen_server:call(Name, {register, {Pid, 0}})
    end.

unregister_worker(Name, {Pid, Port}) ->
   
   ?Trace({unregister, {Pid, Port}}),

      gen_server:call(Name, {unregister, {Pid, Port}}).


%% start/stop worker

start_worker(Name, Cmd) ->
    ?Trace({call_start_worker, Name, Cmd, no}),
    gen_server:call(Name, {start_worker, Cmd, no}).

start_worker(Name, Cmd, C) ->
    ?Trace({call_start_worker, Name, Cmd, C}),
    gen_server:call(Name, {start_worker, Cmd, C}).


start_all_workers(Name, Cmd) ->
    case start_worker(Name, Cmd, no) of 

       full_limit -> {ok, full_limit};
        _ -> start_all_workers(Name, Cmd)

    end.

start_all_workers(Name, Cmd, C) ->
    case start_worker(Name, Cmd, C) of 

       full_limit -> {ok, full_limit};
        _ -> start_all_workers(Name, Cmd, C)

    end.


stop_all_workers(Name) ->
    gen_server:call(Name, {stop_all_workers, 0}).

stop_all_workers(Name, C) ->
    gen_server:call(Name, {stop_all_workers, C}).


cap_workers(Name, Cmd, C) ->

    {ok, full_limit}=ppool_worker:start_all_workers(Name, Cmd, C),
     ppool_worker:stop_all_workers(Name, C).
 

%% API

call_worker(Name, Msg) ->
    gen_server:call(Name, {call_worker, {msg, no, Msg}}).

call_worker(Name, Ref, Msg) ->
    gen_server:call(Name, {call_worker, {msg, Ref, Msg}}).
  

first_call_worker(Name, Msg) ->
    gen_server:call(Name, {first_call_worker, {msg, no, Msg}}).


cast_worker(Name, Msg) ->
    gen_server:cast(Name, {cast_worker, {msg, no, Msg}}).

cast_worker(Name, Ref, Msg) ->
    gen_server:cast(Name, {cast_worker, {msg, Ref, Msg}}).


dcast_worker(Name, Ref, Msg) ->
    gen_server:cast(Name, {cast_worker, {dmsg, Ref, Msg}}).

dacast_worker(Name, Ref, Msg) ->
    gen_server:cast(Name, {cast_worker, {dmsga, Ref, Msg}}).


cast_worker_defer(Name, Msg) ->
    gen_server:call(Name, {cast_worker_defer, Msg}).


cast_all_workers(Name, Msg) ->
    gen_server:cast(Name, {cast_all_workers, {msg, no, Msg}}).


cast_all_workers(Name, Ref, Msg) ->
    gen_server:cast(Name, {cast_all_workers, {msg, Ref, Msg}}).


set_status_worker(Name, Pid, S) ->
    gen_server:cast(Name, {set_status_worker, Pid, S}).


get_result_worker(Name, Msg) ->
    gen_server:call(Name, {get_result_worker, Msg}).


subscribe(Name, {S, Filter, API}) ->
    gen_server:cast(Name, {subscribe, S, Filter, API}).

unsubscribe(Name, S) ->
    gen_server:cast(Name, {unsubscribe, S}).


add_nomore_info(Name) ->
    gen_server:cast(Name, {add_nomore_info}).


   
%% callbacks

handle_call({start_worker, Cmd, C}, _From, #state{name=Name, workers_pids=Pids,
                                                  limit=Limit}=State) 
  when C=:=no ->

   Cr = length(maps:keys(Pids)),

   case Cr < Limit of
       true ->

        ?Trace({call_start_worker_limit, Limit}),
 
         {ok, Pid} = supervisor:start_child(
                       list_to_atom(atom_to_list(Name)++"_sup"),
                       [Cmd]),

               {reply, Pid, State#state{workers_pids=maps:put(Pid, -1, Pids)}};
       false ->
           {reply, full_limit, State}

     end;


handle_call({start_worker, Cmd, C}, _From, #state{name=Name, workers_pids=Pids}=State)

 when C =/= no, C >= 0 ->

  NewLimit = C,

   Cr = length(maps:keys(Pids)),

   case Cr < NewLimit of
       true ->

        ?Trace({call_start_worker_limit, NewLimit}),
 
         {ok, Pid} = supervisor:start_child(
                       list_to_atom(atom_to_list(Name)++"_sup"),
                       [Cmd]),

               {reply, Pid, State#state{limit=NewLimit, workers_pids=maps:put(Pid, -1, Pids)}};

       false ->
           {reply, full_limit, State#state{limit=NewLimit}}

     end;


handle_call({start_worker, _, C}, _From, State)
 when C =/= no, C < 0 ->
    
    {reply, full_limit, State};


handle_call({stop_all_workers, C}, _From, 
                       #state{workers_pids=Pids, async=Async, 
                              stream=Stream}=State) ->

    Cr = length(maps:keys(Pids)),

    ?Trace({stop_all_workers, Cr, C}),

    Free = case Stream or Async of
             false ->
                 maps:filter(fun(_K, V) -> V=/=2 end ,Pids);
             true ->
                 maps:filter(fun(_K, V) -> V=/=-1 end ,Pids)
         end,

    ?Trace({stop_all_workers, free, Free}),

    case C=:=0 of
        true ->
             lists:foreach(fun(Pid) ->
                                   gen_server:cast(Pid, {msg, no, stop}) end, 
                                   maps:keys(Free)
                           );

        false ->

            case C > 0 andalso Cr - C > 0 of
                true -> 
                ?Trace({stop, split(maps:keys(Free), Cr-C)}),
                    lists:foreach(fun(Pid) ->
                                        gen_server:cast(Pid, {msg, no, stop}) end, 
                                        split(maps:keys(Free), Cr-C)
                                );
                false ->
                    ok
            end

       end,

	   {reply, ok, State};


handle_call({register, {Pid, Port}}, _From, 
             #state{workers_pids=Pids, ports_pids=Ports}=State) ->

    erlang:monitor(process, Pid),

     {reply, ok, 
       State#state{workers_pids=maps:put(Pid, 0, Pids), 
                   ports_pids=maps:put(Pid, Port, Ports)}};


handle_call({unregister, {Pid, _Port}}, _From, 
             #state{workers_pids=Pids, ports_pids=Ports}=State) ->

    	{reply, ok, State#state{workers_pids=maps:remove(Pid, Pids), 
                                ports_pids=maps:remove(Pid, Ports)}};


handle_call({call_worker, _Msg}, _From, #state{async=Async}=State) 
  when Async =:= true ->
 	{reply, {ok, []}, State};

handle_call({call_worker, Msg}, _From, #state{workers_pids=Pids, async=Async}=State) 
  when Async =:= false ->
    
    Free=maps:filter(fun(_K, V) -> V=/=2 andalso V=/=-1 end ,Pids),

    ?Trace(Free),

    case maps:keys(Free) of
          [] -> 
              {reply, {ok, []}, State};

          [P|_] -> 
            R=gen_server:call(P, Msg),

              {reply, {ok, R}, State}

      end;


handle_call({first_call_worker, Msg}, _From, 
            #state{name=Name, workers_pids=Pids}=State) ->
    
    Free=maps:filter(fun(_K, V) -> V=/=2 andalso V=/=-1 end, Pids),

     case ets:first(Name) of

          '$end_of_table'-> 
            ?Trace({first_call_worker, Name, Free}),

            case maps:keys(Free) of 
                [] -> ok;
                 [P|_] ->
                    _ = gen_server:call(P, Msg)
             end,

              {reply, {ok, call}, State};

          _ -> 
            ?Trace({first_call_worker, already_started, Name}),

              {reply, {ok, []}, State}

      end;

handle_call({cast_worker_defer, Msg}, {From,_}, #state{name=Name, workers_pids=Pids, 
                                                       async=Async, ports_pids=Ports}=State) 
  when Async =:= true ->
 
        Free=maps:filter(fun(_K, V) -> V>=2 end, Pids),

           case map_size(Free) of
               0 ->
                   {reply, {error, noproc}, State};

               _ ->

                  List = maps:to_list(Free),
                  [{P0, _}|_] = lists:keysort(2, List),

		           ?Trace({cast_worker_defer, List, P0, Ports, maps:get(P0,Ports)}),

	                spawn_link(fun() -> ok=new_ets_msg(Name, From, Msg, P0, Ports) end), 

                     {reply, {ok, ok}, State}
           end;


handle_call({cast_worker_defer, Msg}, {From,_}, #state{name=Name, workers_pids=Pids, 
                                                       async=Async}=State) 
    when Async =:=false ->
    
    Free=maps:filter(fun(_K, V) -> V=/=2 andalso V=/=-1 end ,Pids),
    ?Trace({cast_worker_defer, From, self(), Msg, Free}),

    case maps:keys(Free) of
          [] -> 

           ppool_worker:add_nomore_info(Name),

           Pidss2=maps:filter(fun(_K, V) -> V=/=-1 end ,Pids),

           case maps:keys(Pidss2) of
               [] ->
                   {reply, {error, noproc}, State};

               Pidss ->

                  Index = rand:uniform(length(Pidss)),
                   P0=lists:nth(Index, Pidss),

                 R=gen_server:cast(P0, {msg_defer, no, Msg, From}),
                   {reply, {ok, R}, State}
           end;

          [P|_] -> 

             R=gen_server:cast(P, {msg_defer, no, Msg, From}),
              {reply, {ok, R}, State}

      end;


handle_call({get_result_worker, Msg}, _From, #state{name=Name}=State) ->

    ?Trace({Name, Msg}),

     R = ets:select(Name, 
                   ets:fun2ms(fun(N=#worker_stat{ref=P}) 
                                    when P=:=Msg -> N 
                              end)
                  ),

	        {reply, {ok, R}, State};


handle_call(_Request, _From, State) ->
	{reply, ignored, State}.


handle_cast({add_nomore_info},  #state{nomore=C}=State) ->
    {noreply, State#state{nomore=C + 1}};


handle_cast({cast_worker, {_, _, Msg}}, #state{name=Name, workers_pids=Pids, 
                                               async=Async, ports_pids=Ports}=State) 
  when Async=:=true ->

   Free = maps:filter(fun(_K, V) -> V>=2 end, Pids),

   _ = case map_size(Free) of
        0 -> ok;
        _ ->
            List = maps:to_list(Free),
            [{Pid, _}|_] = lists:keysort(2, List),

            ?Trace({cast_worker_random, List, Pid}),
               spawn_link(fun() -> ok=new_ets_msg(Name, no, Msg, Pid, Ports) end)
     end,

      {noreply, State};

 
handle_cast({cast_worker, Msg},  #state{name=Name, workers_pids=Pids, async=Async}=State) 
   when Async=:=false ->

    Free=maps:filter(fun(_K, V) -> V=/=2 andalso V=/=-1 end ,Pids),

    ?Trace(Free),

    case maps:keys(Free) of
          [] -> 

           ppool_worker:add_nomore_info(Name),

            %% get random pid
            List=maps:keys(Pids),

                case length(List) of
                    0 -> ok;
                    L ->
                        Index = rand:uniform(L),
                        Pid=lists:nth(Index, List),
                        ?Trace({cast_worker_random, Pid}),
                        gen_server:cast(Pid, Msg)
                end;

          [P|_] -> 

            ok=gen_server:cast(P, Msg)

      end,

      {noreply, State};


handle_cast({cast_all_workers, {_, _, Msg}}, #state{name=Name, workers_pids=Pids, 
                                                 async=Async, ports_pids=Ports}=State) 
  when Async =:= true ->

   List=maps:filter(fun(_K, V) -> V>=2 end ,Pids),

    ?Trace(List),

        lists:foreach(fun(Pid) ->

                     ?Trace({cast_all_async, Msg, Pid}),

 	                   spawn_link(fun() -> ok=new_ets_msg(Name, no, Msg, Pid, Ports) end)

                         end,
                     maps:keys(List)),

	        {noreply, State};


handle_cast({cast_all_workers, Msg},  #state{workers_pids=Pids, async=Async}=State)
   when Async =:=false ->

    ?Trace(Pids),

        lists:foreach(fun(Pid) -> gen_server:cast(Pid, Msg) end,
                                   maps:keys(Pids)),

	        {noreply, State};


handle_cast({set_status_worker, Pid, S},
            #state{workers_pids=Pids}=State) ->

            Cnt=maps:get(Pid, Pids),
            
            case S of
              inc ->
                 ?Trace({set_status_worker_inc, Pid, Cnt, S}),
 
                 {noreply, State#state{workers_pids=maps:update(Pid, Cnt+1, Pids)}};

              decr ->
                 ?Trace({set_status_worker_decr, Pid, Cnt, S}),

                  {noreply, State#state{workers_pids=maps:update(Pid, Cnt-1, Pids)}};

              N ->
           	      {noreply, State#state{workers_pids=maps:update(Pid, N, Pids)}}

            end;


handle_cast({subscribe, S, Filter, API}, #state{name=Name}=State) ->

    Ev = list_to_atom(atom_to_list(Name)++"_ev"),

     case lists:member({ppool_ev, S}, gen_event:which_handlers(Ev)) of
        false ->
                gen_event:add_sup_handler(Ev, {ppool_ev, S}, 
                                          [S, Filter, API]);
        true -> ok
    end,

    	{noreply, State};



handle_cast({unsubscribe, S}, #state{name=Name}=State) ->

    gen_event:delete_handler(list_to_atom(atom_to_list(Name)++"_ev"), 
                              {ppool_ev, S},[]),
    	{noreply, State};


handle_cast(_Msg, State) ->
	{noreply, State}.


handle_info({'DOWN', _MonitorRef, process, Pid, _Info}, 
            #state{workers_pids=Pids, ports_pids=Ports}=State) ->

    	{noreply, State#state{workers_pids=maps:remove(Pid, Pids), 
                              ports_pids=maps:remove(Pid, Ports)}};


handle_info(send_nomore, #state{name=Name, nomore=C}=State) ->

   %% send nomore info
    
      case C > 0 of
        true ->
          %% notify system 
            Msg2=erlang:list_to_binary(["system::warning::nomore::", 
                atom_to_list(node()),"::",
                atom_to_list(Name), "::", erlang:integer_to_list(C), "\n"]),

              lists:foreach(fun(Pidd) -> 
                                    ppool_worker:cast_worker(Pidd, Msg2)   
                            end,    
                           pg:get_members(?NO_MORE_PPOOL));
          %%%%%%
        false ->
              ok
      end,

    erlang:send_after(?INTERVAL_NOMORE, self(), send_nomore),

    {noreply, State#state{nomore=0}};


handle_info(clean_ets, #state{name=Name}=State) ->

   {M, S, _} = os:timestamp(),
        
    R = ets:select(Name, 
                   ets:fun2ms(fun(N=#worker_stat{time_end=P, status=St}) 
                                    when P=/=undefined 
                                         andalso St=/=running
                                         andalso P < {M, S-65, _}

                                         -> N 
                              end)
                  ),

       [ets:delete(Name, K#worker_stat.ref) || K <- R],

         erlang:send_after(?INTERVAL, self(), clean_ets),

           {noreply, State};



handle_info({'EXIT', _Pid, normal}, State) ->
     {noreply, State};

handle_info({'EXIT', _Pid, _Reason}, State) ->
    ?Trace({exit, shutwon}),
        {stop, error, State};


handle_info(_Info, State) ->
     {noreply, State}.


terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.


new_ets_msg(Name, From, Msg, P0, Ports) ->

     Ref={node(), self(), os:timestamp()},

     {X1, X2, {X3, X4, X5}} = Ref,

     Sref = erlang:list_to_binary([erlang:atom_to_list(X1), ":", 
                                    erlang:pid_to_list(X2) , ":",
                                    erlang:integer_to_binary(X3), ":",
                                    erlang:integer_to_binary(X4), ":",
                                    erlang:integer_to_binary(X5)
                                   ]),

      ?Trace({new_async_msg_defer, Ref, Sref}),

        MsgL = case os:getenv("ETS_REQ_RES", "yes") of
                    "yes" -> Msg;
                    "no" -> no
                end,

       true=ets:insert(Name, #worker_stat{ref=Ref, 
                                     ref_from=no, pid=self(),cmd=Name,
                                     req=MsgL, status=running,
                                     time_start=os:timestamp()}
                        ),

        FromS = case From of
            no ->
                <<"no">>;
            F ->
                erlang:pid_to_list(F)
        end,

          Msg2=erlang:list_to_binary([FromS , ":",
                                      Sref , "::",
                                      Msg]),

 	        ppool_worker:set_status_worker(Name, P0, inc),

	         port_command(maps:get(P0, Ports), Msg2),
        
              ok.


split([], _I) ->
    [];

split(A, I) ->
    split(A, I, []).

split(_, I, R) when I =:= 0 ->
    R;

split(A, I, _) when I > length(A) ->
    A;
 
split(A, I, R) when I > 0 ->
    [H| T] = A,
        split(T, I-1, [H|R]).

