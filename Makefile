PROJECT = ppool
PROJECT_DESCRIPTION = Core App /Distribued Reliable Operation Platform
PROJECT_VERSION = 0.1.0

ERLC_OPTS= -Dtrace
ERL_COMPILE_FLAGS= -Dtrace
EUNIT_ERL_OPTS = -kernel start_pg true

BUILD_DEPS = cowboy
dep_cowboy_commit = 2.9.0
DEP_PLUGINS = cowboy

include erlang.mk

.PHONY: run exec build_test_workers clean_test_workers

exec:
	@erl -pa ebin -kernel start_pg true -s main

run:
	@./scripts/drop-core start

build_test_workers:
	@cd test/workers && erlc *.erl && cd -
	@cd test/workers && rustc port_worker.rs && cd -
	@cd test/workers && rustc port_worker_stream.rs && cd -
	@cd test/workers && rustc port_worker_async.rs && cd -
	@cp test/workers/port_worker_stream priv/flower_sc_stream/flower_sc_stream
	@cp test/workers/port_worker_stream priv/node_info_stream/node_info_stream
	@cp test/workers/port_worker priv/flower/flower
	@cp test/workers/port_worker priv/node_collector/node_collector


clean_test_workers:
	@cd test/workers && rm port_worker && cd -
	@cd test/workers && rm port_worker_stream && cd -
	@cd test/workers && rm port_worker_async && cd -
	@cd test/workers && rm -rf *.beam && cd -
	@rm priv/flower_sc_stream/flower_sc_stream
	@rm priv/node_info_stream/node_info_stream
	@rm priv/flower/flower
	@rm priv/node_collector/node_collector
