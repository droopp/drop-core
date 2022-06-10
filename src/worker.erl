-module(worker).
-behaviour(gen_server).

%% API.
-export([start_link/2]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-include("ppool.hrl").

-record(state, {
          master,
          ev,
          port,
          cmd,
          timeout
}).

%% API.

start_link(N, Cmd) ->
 
	gen_server:start_link(?MODULE, {N, Cmd}, []).

%% gen_server.

init({N, Cmd}) ->

    ?Trace({N, Cmd,  self()}),
     {C, T}=Cmd,

      process_flag(trap_exit, true),

	    {ok, #state{master=N, 
                    ev=list_to_atom(atom_to_list(N)++"_ev"),
                    cmd=C, timeout=T}, 0}.



handle_call({msg, R, Msg}, From, #state{master=N, ev=E, cmd=Cmd, timeout=T,
                                        port=Port}=State) ->

    ?Trace(Msg),
     Ref = new_ets_msg(N, Cmd, R, Msg),

      gen_server:reply(From, Ref),
 
       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> {stop, port_timeout, State};
            {error, 1, _} -> {stop, error, State};

            _ -> {noreply, State}
       end;


handle_call({sync_msg, R, Msg}, _From, #state{master=N, ev=E,
                                           cmd=Cmd, timeout=T, 
                                           port=Port}=State) ->
 
    Ref = new_ets_msg(N, Cmd, R, Msg),

        case process_ets_msg(N, E, Port, Ref, Msg, T) of
            {ok, Response} -> 
                {reply, {ok, Response}, State};

            {error, 1, _} ->
                {stop, error, State};

            {error, timeout} ->
                 {stop, port_timeout, State}
        end;


handle_call(stop, From, State) ->

    ?Trace({stop, self()}),
     gen_server:reply(From, ok),

       {stop, normal, State};


handle_call(_Request, _From, State) ->
	{reply, ignored, State}.


handle_cast({msg, _, restart}, State) ->
    {stop, restart, State};

handle_cast({msg, _, stop}, #state{master=M, port=Port}=State) ->

    Qlen=erlang:process_info(self(), message_queue_len),
     ?Trace({message_queue_len, Qlen}),

    case Qlen of
        {_, 0} ->

            ppool_worker:unregister_worker(M, {self(), Port}),

            {stop, normal, State};
        _ ->
            {noreply, State}
    end;  


handle_cast({msg, R, Msg}, #state{master=N, ev=E, cmd=Cmd, 
                                  timeout=T, port=Port}=State) ->

    Ref = new_ets_msg(N, Cmd, R, Msg),
 
       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> {stop, port_timeout, State};
           {error, 1, _} -> {stop, error, State};
            _ -> {noreply, State}

       end;


handle_cast({dmsga, R, Msg}, #state{master=N}=State) ->

   ?Trace({start_distrib_dmsga, R, Msg}),
   ?Trace({pg_group, pg:get_members(N)}),

     Arr = pg:get_members(N),
      ?Trace({remote, Arr}),
       [ppool_worker:cast_worker(X, R, Msg)||X<-Arr],

         ?Trace({noreply_send, self()}),
 
           {noreply, State};


handle_cast({dmsg, R, Msg}, #state{master=N}=State) ->

   ?Trace({start_distrib_dmsg, R, Msg}),
   ?Trace({pg_group, pg:get_members(N)}),

    case pg:get_members(N) of
        
        [Ms] -> %% local 
           ?Trace({local, Ms}),
            ppool_worker:cast_worker(Ms, R, Msg);

        Arr ->
           ?Trace({remote, Arr}),
            Index = rand:uniform(length(Arr)),
            NewP=lists:nth(Index, Arr),

             ?Trace({remote_choise_to, NewP}),
 
              ppool_worker:cast_worker(NewP, R, Msg)

      end,

       ?Trace({noreply_send, self()}),
 
        {noreply, State};


handle_cast({stream_msg, R, Msg}, #state{master=N, ev=E, cmd=Cmd, 
                                         timeout=T, port=Port}=State) ->

    Ref = new_ets_msg(N, Cmd, R, Msg),

     Port!Msg,
 
       case process_stream_ets_msg(N, E, Port, Ref, Msg, T, os:timestamp()) of
           {error, timeout} -> {stop, port_timeout, State};
           {error, 1, _} -> {stop, error, State}

       end;


handle_cast({msg_defer, R, Msg, From}, #state{master=N, ev=E, cmd=Cmd,
                                              port=Port, timeout=T}=State) ->

    ?Trace({msg_defer, From, Msg}),

     Ref = new_ets_msg(N, Cmd, R, Msg),

       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> 
               From!{response, timeout},

               {stop, port_timeout, State};

           Res -> 
               From!{response, Res},

               {noreply, State}

       end;

handle_cast(_Msg, State) ->
	{noreply, State}.


handle_info(timeout, #state{master=M, cmd=Cmd}=State) ->

    ?Trace({open_port, Cmd}),

     Pid = self(),

     {Fn, Port} = case Cmd of
       {Md, F} ->
          {F, spawn_link(fun() -> Md:F(Pid) end)};
       {Md, F , A} ->
          {F, spawn_link(fun() -> Md:F(Pid, A) end)}
       end,

       ?Trace({registering, self()}),
        ppool_worker:register_worker(M, self()),

        %% if stream type do start

        case string:find(erlang:atom_to_list(Fn), "_stream") of
            nomatch -> ok;
            _ -> ppool_worker:stream_all_workers(M, <<"start\n">>)
        end,

	     {noreply, State#state{port=Port}};


handle_info({'EXIT', Port, Reason}, #state{port=Port}=State) ->
    ?Trace({exit, Reason}),
        {stop, {port_terminated, Reason}, State};

handle_info(_Info, State) ->
	{noreply, State}.


terminate({port_terminated, _Reason}, _State) ->
    ok;


terminate(_Reason, #state{port=Port}=_State) ->

  try exit(Port, kill) of
        _ -> ok
    catch 
        _:_ -> ok
    end;


terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.


collect_response(Port, T) ->
   receive
        {Port, {data, Data}} ->
            {ok, Data};

        {'EXIT', _From, Reason} ->
             {error, 1, Reason }

    after
         T ->
            {error, timeout}
    end.



new_ets_msg(N, _Cmd, R, Msg) ->

    ?Trace({new_ets_msg, self()}),

     Ref={node(), self(), os:timestamp()},

      true=ets:insert(N, #worker_stat{ref=Ref, 
                                      ref_from=R, pid=self(),cmd=N,
                                      req=Msg, status=running,
                                      time_start=os:timestamp()}
                        ),

       ppool_worker:set_status_worker(N, self(), 2),

        Ref.


process_ets_msg(N, E, Port, Ref, Msg, T) ->

      Port!Msg,

        case collect_response(Port, T) of

            {ok, Response} -> 

                true=ets:update_element(N, Ref, [
                                               {#worker_stat.status, ok},
                                               {#worker_stat.result, no},
                                               {#worker_stat.time_end, os:timestamp()}
                                ]),

                  ppool_worker:set_status_worker(N, self(), 1),
                  gen_event:notify(E, {msg, {ok, Ref, Response}}),

                {ok, Response};

            {error, Status, Err} ->

                true=ets:update_element(N, Ref, [
                                 {#worker_stat.status, error},
                                 {#worker_stat.result, Err},
                                 {#worker_stat.time_end, os:timestamp()}
                                ]),

                 Msg2=erlang:list_to_binary(["system::error::", 
                      atom_to_list(node()),"::",
                      atom_to_list(N)]),
 
                  gen_event:notify(E, {msg, {error, Ref, [Msg2]}}),
                   timer:sleep(?ERROR_TIMEOUT),

                    {error, Status, Err};

            {error, timeout} ->

                true=ets:update_element(N, Ref, [
                                 {#worker_stat.status, timeout},
                                 {#worker_stat.time_end, os:timestamp()}
                                ]),

                 Msg2=erlang:list_to_binary(["system::timeout::", 
                      atom_to_list(node()),"::",
                      atom_to_list(N)]),

                   gen_event:notify(E, {msg, {error, Ref, [Msg2]}}),
                    timer:sleep(?ERROR_TIMEOUT),

                    {error, timeout}
        end.


process_stream_ets_msg(N, E, Port, Ref, Msg, T, LastTime) ->

        case collect_response(Port, T) of

            {ok, Response} ->

                  gen_event:notify(E, {msg, {ok, Ref, Response}}),

                     Ref2={node(), self(), os:timestamp()},

                     FinTime = os:timestamp(),

                     true=ets:insert(N, #worker_stat{ref=Ref2,
                                                     ref_from=no, pid=self(),cmd=N,
                                                     req=Msg, status=ok, result=no,
                                                     time_start=LastTime,
                                                     time_end=FinTime}
                                        ),

                    process_stream_ets_msg(N, E, Port, Ref, Msg, T, FinTime);

            {error, Status, Err} ->

                true=ets:update_element(N, Ref, [
                                 {#worker_stat.status, error},
                                 {#worker_stat.result, Err},
                                 {#worker_stat.time_end, os:timestamp()}
                                ]),

                 Msg2=erlang:list_to_binary(["system::error::", 
                      atom_to_list(node()),"::",
                      atom_to_list(N)]),
 
                   gen_event:notify(E, {msg, {error, Ref, [Msg2]}}),
                    timer:sleep(?ERROR_TIMEOUT),

                      {error, Status, Err};

            {error, timeout} ->

                true=ets:update_element(N, Ref, [
                                 {#worker_stat.status, timeout},
                                 {#worker_stat.time_end, os:timestamp()}
                                ]),

                 Msg2=erlang:list_to_binary(["system::timeout::", 
                      atom_to_list(node()),"::",
                      atom_to_list(N)]),

                   gen_event:notify(E, {msg, {error, Ref, [Msg2]}}),
                     timer:sleep(?ERROR_TIMEOUT),

                       {error, timeout}
        end.

