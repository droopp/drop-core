{application, 'node_scheduler', [
	{description, "Drop node_scheduler"},
	{vsn, "0.1.0"},
	{modules, ['node_scheduler','node_scheduler_app','node_scheduler_sup']},
	{registered, [node_scheduler_sup]},
	{applications, [kernel,stdlib]},
	{mod, {node_scheduler_app, []}},
	{env, []}
]}.