PROJECT = ppool
PROJECT_DESCRIPTION = Core DROP App /Distribued Reliable Operation Platform
PROJECT_VERSION = 0.1.0

DEPS = cowboy
dep_cowboy_commit = 2.4.0
DEP_PLUGINS = cowboy

ERLC_OPTS= -Ddebug0

include erlang.mk

run:
	./scripts/drop-core start
