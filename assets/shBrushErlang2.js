var erl = {
    bifs: /\b(?:abs|alive|apply|atom_to_list|binary_to_list|binary_to_term|concat_binary|date|disconnect_node|element|erase|exit|float|float_to_list|get|get_keys|group_leader|halt|hd|integer_to_list|is_alive|length|link|list_to_atom|list_to_binary|list_to_float|list_to_integer|list_to_pid|list_to_tuple|load_module|make_ref|monitor_node|node|nodes|now|open_port|pid_to_list|process_flag|process_info|process|put|register|registered|round|self|setelement|size|spawn|spawn_link|split_binary|statistics|term_to_binary|throw|time|tl|trunc|tuple_to_list|unlink|unregister|whereis|atom|binary|constant|function|integer|list|number|pid|ports|port_close|port_info|reference|record|check_process_code|delete_module|get_cookie|hash|math|module_loaded|preloaded|processes|purge_module|set_cookie|set_node|acos|asin|atan|atan2|cos|cosh|exp|log|log10|pi|pow|power|sin|sinh|sqrt|tan|tanh|call|module_info|parse_transform|undefined_function|error_handler|creation|current_function|dictionary|group_leader|heap_size|high|initial_call|linked|low|memory_in_use|message_queue|net_kernel|node|normal|priority|reductions|registered_name|runnable|running|stack_trace|status|timer|trap_exit|waiting|command|count_in|count_out|creation|in|in_format|linked|node|out|owner|packeting|atom_tables|communicating|creation|current_gc|current_reductions|current_runtime|current_wall_clock|distribution_port|entry_points|error_handler|friends|garbage_collection|magic_cookie|magic_cookies|module_table|monitored_nodes|name|next_ref|ports|preloaded|processes|reductions|ref_state|registry|runtime|wall_clock|apply_lambda|module_info|module_lambdas|record|record_index|record_info|badarg|nocookie|false|badsig|kill|killed|exit|normal)(?=\(.*\))/g,
    keywords: /\b(?:div|rem|or|xor|bor|bxor|bsl|bsr|and|band|not|bnot|after|begin|case|catch|cond|end|fun|if|let|of|query|receive|when|letrec|try|then|else)\b/g,
    functions: /[^\r\na-zA-Z0-9_](?:(?:[a-z][a-zA-Z0-9_]+:)?[a-z][a-zA-Z0-9_]+)(?=\()/g,
    preproc: /-compile|-define|-else|-endif|-export|-file|-ifdef|-ifndef|-import|-include|-include_lib|-module|-record|-undef|-author|-copyright|-doc|-spec|-type/g,
    numerics: /\b[+-]?(?:(?:0x[A-Fa-f0-9]+)|(?:(?:[\d]*\.)?[\d]+(?:[eE][+-]?[\d]+)?))u?(?:(?:int(?:8|16|32|64))|L)?\b|\$\x+/g,
    symbols: /==|=:=|=\/=|=&lt;|&gt;=|\+\+|--|!|&lt;-|-&gt;|_|@|\\|\"|\+|-|\*|=|&gt;|&lt;|\/|\.|;|\|/g,
    bitstrings: /&lt;&lt;"(?:\.|(\\\")|[^\""])*"&gt;&gt;/g,
    atoms: /\b[a-z][a-zA-Z0-9@_.]*\b(?!\()/g
};

SyntaxHighlighter.brushes.Erlang = function(){
	this.regexList = [
	  { regex: new RegExp('%.*$', 'gm'), css: 'comments' },   // one line comments  
	  { regex: erl.bitstrings, css: 'string' },
	  { regex: SyntaxHighlighter.regexLib.multiLineDoubleQuotedString, css: 'string' },   // strings  
	  { regex: SyntaxHighlighter.regexLib.singleQuotedString, css: 'atoms' }, 
      { regex: erl.bifs, css: 'functions' },
	  { regex: erl.keywords,  css: 'keyword' },
	  { regex: erl.preproc,  css: 'preprocessor' },
	  { regex: erl.functions, css: 'functions'},
      { regex: erl.numerics, css: 'numerics' },
	  { regex: erl.atoms, css: 'atoms'},
	  { regex: erl.symbols, css: 'symbols'}
	];
};
SyntaxHighlighter.brushes.Erlang.prototype = new SyntaxHighlighter.Highlighter();
SyntaxHighlighter.brushes.Erlang.aliases = ['erl','hrl'];

SyntaxHighlighter.brushes.Eshell = function(){
	this.regexList = [
	  { regex: new RegExp('^(?:\\(.+@.+\\))??[\s0-9]+\&gt;','gm'), css: 'comments'},
	  { regex: new RegExp('^\\*+.*','gm'), css: 'errors'}, // shell errors
      { regex: new RegExp('^[^0-9(].*','gm'), css: 'shell_output'},
      { regex: new RegExp('^[0-9.]+$','gm'), css: 'shell_output'}, // only integers!
	  { regex: new RegExp('%.*$', 'gm'), css: 'comments' },   // one line comments  
	  { regex: erl.bitstrings, css: 'string' },
	  { regex: SyntaxHighlighter.regexLib.multiLineDoubleQuotedString, css: 'string' },   // strings  
	  { regex: SyntaxHighlighter.regexLib.singleQuotedString, css: 'atoms' }, 
      { regex: erl.bifs, css: 'functions' },
	  { regex: erl.keywords,  css: 'keyword' },
	  { regex: erl.preproc,  css: 'preprocessor' },
	  { regex: erl.functions, css: 'functions'},
      { regex: erl.numerics, css: 'numerics' },
	  { regex: erl.atoms, css: 'atoms'},
	  { regex: erl.symbols, css: 'symbols'}
	];
};
SyntaxHighlighter.brushes.Eshell.prototype = new SyntaxHighlighter.Highlighter();
SyntaxHighlighter.brushes.Eshell.aliases = ['eshell'];
