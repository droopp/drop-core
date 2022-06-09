PROJECT = drop
PROJECT_DESCRIPTION = Core App /Distribued Reliable Operation Platform
PROJECT_VERSION = 0.1.0

ERLC_OPTS= -Dtrace

include erlang.mk

run:
	/opt/erlang/bin/erl -pa ebin -kernel start_pg true -s main
