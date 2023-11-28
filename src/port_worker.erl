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
    ?Trace({N, Cmd, self()}),

     {C, T} = Cmd,

      process_flag(trap_exit, true),

	    {ok, #state{master=N, 
                    ev=list_to_atom(atom_to_list(N)++"_ev"),
                    cmd=C,
                    timeout=T
                   }, 0}.


handle_call({msg, R, Msg}, From, #state{master=N, ev=E, cmd=Cmd, port=Port,
                                       timeout=T}=State) ->

    ?Trace(Msg),

     Ref=new_ets_msg(N, Cmd, R, Msg),
      gen_server:reply(From, Ref),
 
       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> {stop, port_timeout, State};
            _ -> {noreply, State}
       end;


handle_call(stop, From, State) ->

    ?Trace({stop, self()}),

     gen_server:reply(From, ok),

      {stop, normal, State};


handle_call(_Request, _From, State) ->
	{reply, ignored, State}.


handle_cast({msg, _, restart}, State) ->
    {stop, restart, State};

handle_cast({msg, _, stop}, State) ->

   ?Trace({stop, normal, erlang:process_info(self(), message_queue_len) }),

    case erlang:process_info(self(), message_queue_len) of
        {_, 0} ->
            {stop, normal, State};
        _ ->
            {noreply, State}
    end;  


handle_cast({msg, R, Msg}, #state{master=N, ev=E, cmd=Cmd, port=Port, 
                                  timeout=T}=State) ->

    Ref=new_ets_msg(N, Cmd, R, Msg),
 
       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> {stop, port_timeout, State};
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


handle_cast({stream_loop}, #state{master=N, ev=E, cmd=Cmd, port=Port, timeout=T}=State) ->

    Ref = new_ets_msg(N, Cmd, no, <<"start\n">>),
 
       case process_stream_ets_msg(N, E, Port, Ref, T, os:timestamp()) of
           {stop, normal} -> {stop, normal, State};
           {error, timeout} -> {stop, port_timeout, State};
            _ -> {noreply, State}

       end;


handle_cast({async_loop}, #state{master=N, ev=E, port=Port, cmd=Cmd, timeout=T}=State) ->

      ?Trace({async_loop}),

       Ref = new_ets_msg(N, Cmd, no, <<"start\n">>),

       case process_async_ets_msg(N, E, Port, Ref, T) of
            {stop, normal} -> {stop, normal, State};
             _ -> {noreply, State}
      
        end;


handle_cast({msg_defer, R, Msg, From}, #state{master=N, ev=E, cmd=Cmd,
                                              port=Port, timeout=T}=State) ->
    ?Trace({msg_defer, From, Msg}),

     Ref=new_ets_msg(N, Cmd, R, Msg),

       case process_ets_msg(N, E, Port, Ref, Msg, T) of
           {error, timeout} -> 
               From!{response, timeout},

               {stop, port_timeout, State};

           {error, _, _} -> 
               From!{response, error},

               {stop, error, State};

           Res -> 
               From!{response, Res},

               {noreply, State}

       end;


handle_cast(_Msg, State) ->
	{noreply, State}.


handle_info(timeout, #state{master=M, cmd=Cmd}=State) ->

    ?Trace({open_port, Cmd}),

     Port = case Cmd of
         {driver, Path, Name} ->

            case erl_ddll:load_driver(Path, Name) of                              
                ok -> ok;                                                                  
                {error, already_loaded} -> ok;                                             
                _ -> exit({error, could_not_load_driver})                                  
            end,

            open_port({spawn, Name}, [binary]);


         C ->
                    
            open_port({spawn, C}, [{line, 256}, 
                                    exit_status, 
                                    binary])
    
      end,

   
       ?Trace({registering, self()}),

        ppool_worker:register_worker(M, {self(), Port}),

        %% if stream type
        case string:find(erlang:atom_to_list(M), "_stream") of 
            nomatch -> ok;
            _ -> 
                gen_server:cast(self(), {stream_loop})
        end,

         %% if async type
         case string:find(erlang:atom_to_list(M), "_async") of 
            nomatch -> 
               ok;
            _ ->
        	   gen_server:cast(self(), {async_loop})
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
    case T of 
       no ->
    	collect_response(Port, [], <<>>);
       A ->
        collect_response(Port, A, [], <<>>)
     end.

collect_response(Port, T, Lines, OldLine) ->

   receive

        {Port, {data, Data}} ->
            case Data of
                {eol, Line} ->
                    {ok, [<<OldLine/binary,Line/binary>> | Lines]};
                {noeol, Line} ->
                    collect_response(Port, T, Lines, <<OldLine/binary,Line/binary>>);
                <<Bin/binary>> ->
                    {ok, [<<Bin/binary>>]}
            end;

        {Port, {exit_status, Status}} ->
            {error, Status, Lines};

        {_, {msg, _, stop}} ->
           {stop, normal}

    after
         T ->
            {error, timeout}
    end.

collect_response(Port, Lines, OldLine) ->

   receive

        {Port, {data, Data}} ->
            case Data of
                {eol, Line} ->
                    {ok, [<<OldLine/binary,Line/binary>> | Lines]};
                {noeol, Line} ->
                    collect_response(Port, Lines, <<OldLine/binary,Line/binary>>);
                <<Bin/binary>> ->
                    {ok, [<<Bin/binary>>]}
 
            end;

        {Port, {exit_status, Status}} ->
            {error, Status, Lines};

        {_, {msg, _, stop}} ->
           {stop, normal}

    end.


new_ets_msg(N, _Cmd, R, Msg) ->

    ?Trace({new_ets_msg, self()}),

     Ref={node(), self(), os:timestamp()},

        MsgL = case os:getenv("ETS_REQ_RES", "yes") of
                    "yes" -> Msg;
                    "no" -> no
                end,

      true=ets:insert(N, #worker_stat{ref=Ref, 
                                      ref_from=R, pid=self(),cmd=N,
                                      req=MsgL, status=running,
                                      time_start=os:timestamp()}
                        ),

        ppool_worker:set_status_worker(N, self(), 2),

          Ref.


process_async_ets_msg(N, E, Port, Ref, T) ->

        case collect_response(Port, no) of

            {stop, normal} ->

                true=ets:update_element(N, Ref, [
                                               {#worker_stat.status, ok},
                                               {#worker_stat.result, no},
                                               {#worker_stat.time_start, os:timestamp()},
                                               {#worker_stat.time_end, os:timestamp()}
                                ]),
 
            	{stop, normal};

            {ok, [Response0]} -> 

              [SysI, Response] =  binary:split(Response0, <<"::">>),

              [Spid, X1, X2, X3, X4, X5] = binary:split(SysI, <<":">>, [global]),

               DRef = {
                        erlang:list_to_atom(erlang:binary_to_list(X1)),
                        erlang:list_to_pid(erlang:binary_to_list(X2)),

                        { 
                         erlang:binary_to_integer(X3),
                          erlang:binary_to_integer(X4),
                          erlang:binary_to_integer(X5)
                        }
                     
                     },

           	    ?Trace({msg_defer_async_response, N, DRef, Response}),

                MsgL = case os:getenv("ETS_REQ_RES", "yes") of
                            "yes" -> [Response];
                            "no" -> no
                        end,

                 true=ets:update_element(N, DRef, [
                                               {#worker_stat.status, ok},
                                               {#worker_stat.result, MsgL},
                                               {#worker_stat.time_end, os:timestamp()}
                                ]),
 
                  ppool_worker:set_status_worker(N, self(), decr),

	           	  gen_event:notify(E, {msg, {ok, DRef, [Response]}}),

                  _ = case Spid of

                        <<"no">> ->
                            ok;

                        Spid2 ->

                            DFrom = erlang:list_to_pid(erlang:binary_to_list(Spid2)),

                            ?Trace({msg_defer_async_response, DFrom, Response}),
                    
                            DFrom!{response, {ok, [Response]}}
                        end,

                        process_async_ets_msg(N, E, Port, Ref, T);


            {error, Status, Err} ->

                Arr = ets:tab2list(N),

                ?Trace({err_to_update, Arr}),

                [ets:update_element(N, K#worker_stat.ref, [
                                 {#worker_stat.status, error},
                                 {#worker_stat.result, Status},
                                 {#worker_stat.time_start, os:timestamp()},
                                 {#worker_stat.time_end, os:timestamp()}
                                ]) || K <-Arr, K#worker_stat.status =:=running],

                 Msg2=erlang:list_to_binary(["system::error::", 
                      atom_to_list(node()),"::",
                      atom_to_list(N)]),

                  gen_event:notify(E, {msg, {error, Ref, [Msg2]}}),
                   timer:sleep(?ERROR_TIMEOUT),

                    {error, Status, Err}

        end.



process_ets_msg(N, E, Port, Ref, Msg, T) ->

     port_command(Port, Msg),

        case collect_response(Port, T) of

            {ok, Response} -> 

                MsgL = case os:getenv("ETS_REQ_RES", "yes") of
                            "yes" -> Response;
                            "no" -> no
                        end,

                true=ets:update_element(N, Ref, [
                                               {#worker_stat.status, ok},
                                               {#worker_stat.result, MsgL},
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


process_stream_ets_msg(N, E, Port, Ref, T, LastTime) ->

        case collect_response(Port, T) of

            {ok, Response} -> 

                  gen_event:notify(E, {msg, {ok, Ref, Response}}),

    		       Ref2={node(), self(), os:timestamp()},
                   FinTime = os:timestamp(),

                     MsgL = case os:getenv("ETS_REQ_RES", "yes") of
                                "yes" -> Response;
                                "no" -> no
                            end,

		              true=ets:insert(N, #worker_stat{ref=Ref2, 
                                                      ref_from=no, pid=self(),cmd=N,
                                                      req=no, status=ok, result=MsgL,
                                                      time_start=LastTime, time_end=FinTime}
					                  ),

                         process_stream_ets_msg(N, E, Port, Ref, T, FinTime);


            {stop, normal} ->
                true=ets:update_element(N, Ref, [
                                               {#worker_stat.status, ok},
                                               {#worker_stat.result, no},
                                               {#worker_stat.time_start, os:timestamp()},
                                               {#worker_stat.time_end, os:timestamp()}
                                ]),
 
            	{stop, normal};

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
