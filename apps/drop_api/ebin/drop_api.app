{application, 'drop_api', [
	{description, "Drop API"},
	{vsn, "0.1.0"},
	{modules, ['api_handler','drop_api_app','drop_api_sup']},
	{registered, [drop_api_sup]},
	{applications, [kernel,stdlib]},
	{mod, {drop_api_app, []}},
	{env, []}
]}.