-module(api_handler).

-export([init/2]).
-export([info/3]).
-export([terminate/3]).

-include("api_handler.hrl").
-include("../../src/ppool.hrl").


init(Req, State) ->

	 Method = cowboy_req:method(Req),
	 HasBody = cowboy_req:has_body(Req),

     case create_req(Method, HasBody, Req) of
	
	   {ok, Req3, Is_Gzip} ->
             {cowboy_loop, Req3, Is_Gzip};

       {ok, Req3} ->
             {cowboy_loop, Req3, State}
     end.


create_req(<<"POST">>, true, Req) ->
	    Flow = cowboy_req:binding(flow, Req),
        echo(Flow, Req);


create_req(<<"POST">>, false, Req) ->
	Req2=cowboy_req:reply(400, #{}, <<"Missing body">>, Req),
     {ok, Req2};


create_req(_, _, Req) ->
	%% Method not allowed.
	Req2=cowboy_req:reply(405, Req),
     {ok, Req2}.


echo(undefined, Req) ->
	Req2=cowboy_req:reply(400, #{}, <<"Missing flow name">>, Req),
     {ok, Req2};


echo(Flow, Req) ->

    {ok, Body, Req2} = cowboy_req:read_body(Req,  #{length => infinity}),

    L = cowboy_req:body_length(Req),

    ?Trace(L),

    {Pid, Body2, Is_Gzip} = case L of

        L when L<?MAX_BODY_REDIRECT -> 

            P = get_closest_pid(erlang:binary_to_atom(Flow, latin1)),

            {P, Body, false};

        L when L>?MAX_BODY_REDIRECT ->

            P = get_closest_pid(
                    erlang:binary_to_atom(
                      erlang:iolist_to_binary([Flow, <<"_X">>]), latin1)
                   ),

            {P, base64:encode(zlib:gzip(Body)), true}

    end,

    ?Trace({post_req_pid, Pid}),

    _ = case is_pid(Pid) of

        false ->
            self()!{response, {error, mis_req_pool}};

        true ->
            case ppool_worker:cast_worker_defer(Pid, body_to_msg(Body2)) of
                {ok, ok} ->
                    ok;
                 _Err ->
                    self()!{response, {error, mis_run_pool}}

             end
            
    end,

     {ok, Req2, Is_Gzip}.


info({response, Res}, Req, Is_Gzip) ->

  ?Trace({recv_post_req, Res}),

   _ = case Res of
        {ok,[Msg]} ->

         Msg2 = case Is_Gzip of 
             true ->
                  uncompress(Msg); %% zlib:gunzip(Msg);
             _ ->
                 Msg
         end,

          cowboy_req:reply(200, 
                           #{<<"content-type">> => <<"text/plain; charset=utf-8">>}
    	                   ,msg_to_body(Msg2), Req);

        {error, mis_req_pool} ->
            cowboy_req:reply(400, #{}, <<"Missing Registered Pool">>, Req);

        {error, mis_run_pool} ->
            cowboy_req:reply(400, #{}, <<"Missing Running Pool">>, Req);

        _Any ->
            cowboy_req:reply(503, #{}, <<"Error occured">>, Req)
    end,

	{stop, Req, Is_Gzip};


info(Any, Req, State) ->

   error_logger:warning_msg("call no api ~p~n ", [Any]),
 
 	{stop, Req, State}.



terminate({normal, timeout}, _, _) ->
	ok;

terminate(_Reason, _Req, _State) ->
	ok.



msg_to_body(Body) ->
    case binary:last(Body) =:= 10 of
        true ->
            binary:replace(Body, ?SPLIT_MSG_SEQ, <<"\n">>, [global]);

        false ->
            Body2 = binary:replace(Body, ?SPLIT_MSG_SEQ, <<"\n">>, [global]),
           <<Body2/binary, <<"\n">>/binary>>
    end.



body_to_msg(B) ->

   Body = binary:replace(
            binary:replace(B,<<"\r"/utf8>>, <<"\n">>, [global]),
            <<"\n\n">>, <<"\n">>, [global]),
 
    case binary:last(Body) =:= 10 of
        true ->
            Body2 = binary:part(Body, {0, byte_size(Body)-1}),
             Body3 = binary:replace(Body2, <<"\n">>, ?SPLIT_MSG_SEQ, [global]),
              ?Trace({Body, Body2, Body3}),

              <<Body3/binary, <<"\n">>/binary>>;

        false ->
            Body2 = binary:replace(Body, <<"\n">>, ?SPLIT_MSG_SEQ, [global]),
              ?Trace({Body, Body2}),

             <<Body2/binary, <<"\n">>/binary>>
    end.


uncompress(Bin) ->

   Z = zlib:open(),
   zlib:inflateInit(Z, 31),
   
   % hopefully everything fits in memory
   
   Uncompressed = zlib:inflate(Z, 
                               base64:decode(
                                 binary:replace(Bin, ?SPLIT_MSG_SEQ, <<"\n">>, [global])
                                )
                              ),
   
     zlib:inflateEnd(Z),
       zlib:close(Z),

        erlang:list_to_binary(Uncompressed).


get_closest_pid(Name) ->

    case pg:get_local_members(Name) of
        [] ->
            case pg:get_members(Name) of 
                [] ->
                    nil;
                [P|_] ->
                    P
            end;

        [Lp|_] ->
            Lp
    end.
