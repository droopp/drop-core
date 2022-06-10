PROJECT = ppool
PROJECT_DESCRIPTION = Core App /Distribued Reliable Operation Platform
PROJECT_VERSION = 0.1.0
# PROJECT_MOD = ppool_app
# PROJECT_REGISTERED = ppool_sup

ERLC_OPTS= -Dtrace
EUNIT_ERL_OPTS = -kernel start_pg true

include erlang.mk

run:
	/opt/erlang/bin/erl -pa ebin -kernel start_pg true -s main
