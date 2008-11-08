%%%-------------------------------------------------------------------
%%% File    : pm_node.erl
%%% Author  : Ari Lerner <arilerner@mac.com>
%%% The client is a running process that will run on the master node
%%% and spawn requests to the pm_nodes and compile the responses
%%% for use within the poolparty network
%%%-------------------------------------------------------------------
-module(pm_node).
-behaviour(gen_server).

-include_lib("../include/defines.hrl").

%% API
-export([start_link/1, start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {}).
-define(SERVER, ?MODULE).
-define (UPDATE_TIME, 2000).

% Client function definitions
-export ([stop/0]).
-export ([get_load_for_type/1, run_cmd/1, fire_cmd/1]).
-export ([run_reconfig/0, local_update/1, still_here/0]).
-export ([server_location/0]).
%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------


% Get the load for the type sent...
get_load_for_type(Type) ->
	String = string:concat(". /etc/profile && server-get-load -m ",Type),
	{os:cmd(String)}.

% Rerun the configuration
run_reconfig() -> gen_server:cast(server_location(), {run_reconfig}).

% Allows us to fire off any command (allowed by poolparty on the check)
run_cmd(Cmd) -> gen_server:call(server_location(), {run_command, Cmd}).
fire_cmd(Cmd) -> gen_server:cast(server_location(), {fire_command, Cmd}).

still_here() -> gen_server:call(server_location(), {still_there}).

% Stop the pm_node entirely
stop() -> gen_server:cast(server_location(), stop).

% Run every UPDATE_TIME seconds
local_update(Types) ->
	?TRACE("Updating", [?MASTER_LOCATION]),	
	net_adm:ping(?MASTER_LOCATION),
	Load = [{Ty, element(1, get_load_for_type(Ty))} || Ty <- Types],
	gen_server:cast(?MASTER_SERVER, {update_node_load, node(), Load}).
	
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%% 
%% Starts the timer to fire off a ping to the master to let the master
%% know that it is alive
%% 
%% Fires a ping every 10 seconds
%%--------------------------------------------------------------------
start_link() -> start_link(["cpu"]).
start_link(Args) -> gen_server:start_link({global, node()}, ?MODULE, Args, Args).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init(Args) ->
	io:format("Master location ~p~n", [?MASTER_LOCATION]),
	process_flag(trap_exit, true),
	utils:start_timer(?UPDATE_TIME, fun() -> pm_node:local_update(Args) end),
  {ok, #state{}}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call({run_command, Cmd}, _From, State) ->
	Reply = os:cmd(". /etc/profile && server-fire-cmd \""++Cmd++"\""),
	{reply, Reply, State};
handle_call({still_there}, _From, State) ->
	Reply = still_here,
	{reply, Reply, State};
handle_call(_Request, _From, State) ->
  Reply = ok,
  {reply, Reply, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast({fire_command, Cmd}, State) ->
	?TRACE("Running command: ~p~n", [Cmd]),
	os:cmd(". /etc/profile && server-fire-cmd \""++Cmd++"\" 2>&1 > /dev/null"),
	{noreply, State};
handle_cast({run_reconfig}, State) ->
	?TRACE("Running Reconfig", ["server-rerun"]),
	os:cmd(". /etc/profile && server-rerun"),
	{noreply, State};
handle_cast(_Msg, State) ->
	{noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
	io:format("Info message received from: ~p~n", [_Info]),
	{noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
	utils:stop_timer(),
  ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

% Private
server_location() ->
	global:whereis_name(node()).