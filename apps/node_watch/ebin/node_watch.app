{application, 'node_watch', [
	{description, "Drop node_watch"},
	{vsn, "0.1.0"},
	{modules, ['node_watch','node_watch_app','node_watch_sup']},
	{registered, [node_watch_sup]},
	{applications, [kernel,stdlib]},
	{mod, {node_watch_app, []}},
	{env, []}
]}.