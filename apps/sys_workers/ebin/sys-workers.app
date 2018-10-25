{application, 'sys-workers', [
	{description, "System workers libs"},
	{vsn, "0.1.0"},
	{modules, ['sys_pipe']},
	{registered, []},
	{applications, [kernel,stdlib]},
	{env, []}
]}.