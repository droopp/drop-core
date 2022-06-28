PROJECT = ppool
PROJECT_DESCRIPTION = Core App /Distribued Reliable Operation Platform
PROJECT_VERSION = 0.1.0

ERLC_OPTS= -Dtrace
ERL_COMPILE_FLAGS= -Dtrace
EUNIT_ERL_OPTS = -kernel start_pg true

include erlang.mk

.PHONY: run build_test_workers clean_test_workers

run:
	@erl -pa ebin -kernel start_pg true -s main

build_test_workers:
	@cd test/workers && erlc *.erl && cd -
	@cd test/workers && rustc port_worker.rs && cd -
	@cd test/workers && rustc port_worker_stream.rs && cd -
	@cd test/workers && rustc port_worker_async.rs && cd -

clean_test_workers:
	@cd test/workers && rm port_worker && cd -
	@cd test/workers && rm port_worker_stream && cd -
	@cd test/workers && rm port_worker_async && cd -
	@cd test/workers && rm -rf *.beam && cd -

