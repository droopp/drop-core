-module(port_worker).
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
    ?Debug({N, Cmd, self()}),
    {C, T} = Cmd,

      process_flag(trap_exit, true),

	    {ok, #state{master=N, 
                    ev=list_to_atom(atom_to_list(N)++"_ev"),
                    cmd=C,
                    timeout=T
                   }, 0}.




handle_call({msg, R, Msg}, From, #state{master=N, ev=E, cmd=Cmd, port=Port,
                                       timeout=T}=State) ->

    ?Debug(Msg),
    Ref = new_ets_msg(N, Cmd, R, Msg),
      gen_server:reply(From, Ref),
 
       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> {stop, port_timeout, State};
            _ -> {noreply, State}
       end;


handle_call({sync_msg, R, Msg}, _From, #state{master=N, ev=E,
                                              cmd=Cmd, port=Port,
                                              timeout=T}=State) ->
 
    Ref = new_ets_msg(N, Cmd, R, Msg),

        case process_ets_msg(N, E, Port, Ref, Msg, T) of
            {ok, Response} -> 
                {reply, {ok, Response}, State};
            {error, Status, Err} ->
                {reply, {error, Status, Err}, State};
            {error, timeout} ->
                 {stop, port_timeout, State}
        end;


handle_call(stop, From, State) ->
    ?Debug({stop, self()}),
    gen_server:reply(From, ok),
     {stop, normal, State};


handle_call(_Request, _From, State) ->
	{reply, ignored, State}.




handle_cast({msg, _, restart}, State) ->
    {stop, restart, State};

handle_cast({msg, _, stop}, State) ->

    case erlang:process_info(self(), message_queue_len) of
        {_, 0} ->
            {stop, normal, State};
        _ ->
            {noreply, State}
    end;  



handle_cast({msg, R, Msg}, #state{master=N, ev=E, cmd=Cmd, port=Port, 
                                  timeout=T}=State) ->

    Ref = new_ets_msg(N, Cmd, R, Msg),
 
       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> {stop, port_timeout, State};
            _ -> {noreply, State}

       end;



handle_cast({dmsga, R, Msg}, #state{master=N}=State) ->

   ?Debug1({start_distrib_dmsga, R, Msg}),
    ?Debug1({pg_group_a, pg2:get_members(N)}),

    case pg2:get_members(N) of
        Arr ->
           ?Debug1({remote_a, Arr}),
            [ppool_worker:cast_worker(X, R, Msg)||X<-Arr]

    end,
     ?Debug1({noreply_send, self()}),
 
        {noreply, State};



handle_cast({dmsg, R, Msg}, #state{master=N}=State) ->

   ?Debug1({start_distrib_dmsg, R, Msg}),
    ?Debug1({pg_group, pg2:get_members(N)}),

    Ms=whereis(N),

    case pg2:get_members(N) of
        
        [Ms] -> %% local 
           ?Debug1({local, self()}),
            gen_server:cast(self(), {msg, R, Msg});

        Arr ->
           ?Debug1({remote, Arr}),
            Index = rand:uniform(length(Arr)),
             NewP=lists:nth(Index, Arr),

              ?Debug1({remote_choise_to, NewP}),
 
              ppool_worker:cast_worker(NewP, R, Msg)

    end,
     ?Debug1({noreply_send, self()}),
 
        {noreply, State};



handle_cast({stream_msg, R, Msg}, #state{master=N, ev=E, cmd=Cmd, port=Port, 
                                        timeout=T}=State) ->

    Ref = new_ets_msg(N, Cmd, R, Msg),

      port_command(Port, Msg),
 
       case process_stream_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> {stop, port_timeout, State};
            _ -> {noreply, State}

       end;



handle_cast({msg_defer, R, Msg, From}, #state{master=N, ev=E, cmd=Cmd,
                                                port=Port, timeout=T}=State) ->

    ?Debug4({msg_defer, From, Msg}),

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

    ?Debug({open_port, Cmd}),
      Port = open_port({spawn, Cmd},
                           [{line, 256}, 
                              exit_status, binary]),
    
       ?Debug({registering, self()}),
        ppool_worker:register_worker(M, self()),

        %% if stream type do start
        case string:find(Cmd, "_stream") of
            nomatch -> ok;
            _ -> ppool_worker:stream_all_workers(M, <<"start\n">>)
        end,

	  {noreply, State#state{port=Port}};



handle_info({'EXIT', Port, Reason}, #state{port=Port}=State) ->
    ?Debug({exit, Reason}),
        {stop, {port_terminated, Reason}, State};

handle_info(_Info, State) ->
	{noreply, State}.



terminate({port_terminated, _Reason}, _State) ->
    ok;

terminate(_Reason, #state{port=Port}=_State) ->
    try port_close(Port) of
        _ -> ok
    catch 
        _:_ -> ok
    end;

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.




collect_response(Port, T) ->
    collect_response(Port, T, [], <<>>).

collect_response(Port, T, Lines, OldLine) ->
   receive
        {Port, {data, Data}} ->
            case Data of
                {eol, Line} ->
                    {ok, [<<OldLine/binary,Line/binary>> | Lines]};
                {noeol, Line} ->
                    collect_response(Port, T, Lines, <<OldLine/binary,Line/binary>>)
            end;
        {Port, {exit_status, Status}} ->
            {error, Status, Lines}

    after
         T ->
            {error, timeout}
    end.



new_ets_msg(N, Cmd, R, Msg) ->

    ?Debug({new_ets_msg, self()}),

    Ref={node(), self(), os:timestamp()},

     true=ets:insert(N, #worker_stat{ref=Ref, 
                                     ref_from=R, pid=self(),cmd=Cmd,
                                     req=Msg, status=running,
                                     time_start=os:timestamp()}
                        ),

     ppool_worker:set_status_worker(N, self(), 2),


     Ref.


process_ets_msg(N, E, Port, Ref, Msg, T) ->

     port_command(Port, Msg),

        case collect_response(Port, T) of
            {ok, Response} -> 
                true=ets:update_element(N, Ref, [
                                               {#worker_stat.status, ok},
                                               {#worker_stat.result, Response},
                                               {#worker_stat.time_end, os:timestamp()}
                                ]),

                  ppool_worker:set_status_worker(N, self(), 1),
                  gen_event:notify(E, {msg, {ok, Ref, Response}}),

                {ok, Response};

            {error, Status, Err} ->
                true=ets:update_element(N, Ref, [
                                 {#worker_stat.status, error},
                                 {#worker_stat.result, Status},
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


process_stream_ets_msg(N, E, Port, Ref, Msg, T) ->

        case collect_response(Port, T) of
            {ok, Response} -> 
                  gen_event:notify(E, {msg, {ok, Ref, Response}}),
                    process_stream_ets_msg(N, E, Port, Ref, Msg, T);

            {error, Status, Err} ->
                true=ets:update_element(N, Ref, [
                                 {#worker_stat.status, error},
                                 {#worker_stat.result, Status},
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


