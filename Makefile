PROJECT = ppool
PROJECT_DESCRIPTION = Core App /Distribued Reliable Operation Platform
PROJECT_VERSION = 0.1.0

ERLC_OPTS= -Dtrace
EUNIT_ERL_OPTS = -Dtrace -kernel start_pg true

include erlang.mk

.PHONY: run build_test_workers clean_test_workers

run:
	/opt/erlang/bin/erl -pa ebin -kernel start_pg true -s main

build_test_workers:
	cd test/workers && /opt/erlang/bin/erlc *.erl && cd -

clean_test_workers:
	cd test/workers && rm -rf *.beam && cd -
