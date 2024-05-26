package editline

import "core:c"
import "core:c/libc"

// editline v1.17.1
foreign import lib "system:editline"

Status :: enum c.int {
	Done = 0, /* OK */
	EOF,      /* Error, or EOF */
	Move,
	Dispatch,
	Stay,
	Signal,
}

List_Possib_Func :: #type proc "c" (word: cstring, results: ^[^]cstring) -> c.int
Keymap_Func      :: #type proc "c" ()                                    -> Status
Get_C_Func       :: #type proc "c" ()                                    -> c.int
Vcp_Func         :: #type proc "c" (cs: cstring)

Complete_Func    :: #type proc "c" (partial: cstring, n: ^c.int) -> cstring
Comp_Entry_Func  :: #type proc "c" (cs: cstring, i: c.int)       -> cstring
Completion_Func  :: #type proc "c" (cs: cstring, i, j: c.int)    -> [^]cstring

@(link_prefix="el_")
foreign lib {
	no_hist          : c.int
	no_echo          : c.int
	hist_size        : c.int

	find_word           :: proc()                                  -> cstring ---
	@(link_name="el_print_columns")
	_print_columns      :: proc(ac: c.int, av: [^]cstring)         ---
	ring_bell           :: proc()                                  -> Status ---
	del_char            :: proc()                                  -> Status ---

	bind_key            :: proc(key: c.int, function: Keymap_Func) -> Status ---
	bind_key_in_metamap :: proc(key: c.int, function: Keymap_Func) -> Status ---

	next_hist           :: proc()                                  -> cstring ---
	prev_hist           :: proc()                                  -> cstring ---
}

@(link_prefix="rl_")
foreign lib {
	meta_chars       : c.int
	point            : c.int
	mark             : c.int
	end              : c.int
	inhibit_complete : c.int
	line_buffer      : cstring
	readline_name    : cstring
	instream         : libc.FILE
	outstream        : libc.FILE

	attempted_completion_function : Completion_Func

	@(link_name="rl_complete")
	_complete                    :: proc(token: cstring, match: ^c.int)              -> cstring ---
	@(link_name="rl_list_possib")
	_list_possib                 :: proc(token: cstring, av: ^[^]cstring)            -> c.int ---
	completion_matches           :: proc(token: cstring, generator: Comp_Entry_Func) -> [^]cstring ---
	filename_completion_function :: proc(text: cstring, state: c.int)                -> cstring ---

	@(link_name="rl_initialize")
	_initialize           :: proc()                        ---
	reset_terminal        :: proc(terminal_name: cstring)  ---
	@(link_name="rl_uninitialize")
	_uninitialize         :: proc()                        ---

	save_prompt           :: proc()                        ---
	restore_prompt        :: proc()                        ---
	set_prompt            :: proc(prompt: cstring)         ---

	clear_message         :: proc()                        ---
	forced_update_display :: proc()                        ---

	prep_terminal         :: proc(meta_flag: c.int)        ---
	deprep_terminal       :: proc()                        ---

	getc                  :: proc()                        -> c.int ---
	@(link_name="rl_insert_text")
	_insert_text          :: proc(text: cstring)           -> c.int ---
	refresh_line          :: proc(ignore1, ignore2: c.int) -> c.int ---

	set_getc_func         :: proc(func: Get_C_Func)        -> Get_C_Func ---

	set_complete_func     :: proc(func: Complete_Func)     -> Complete_Func ---
	set_list_possib_func  :: proc(func: List_Possib_Func)  -> List_Possib_Func ---

	callback_handler_install :: proc(prompt: cstring, lhandler: Vcp_Func) ---
	callback_read_char       :: proc()                                    ---
	callback_handler_remove  :: proc()                                    ---
}

foreign lib {
	@(link_name="readline")
	_readline                :: proc(prompt: cstring)      -> cstring ---

	@(link_name="add_history")
	_add_history             :: proc(line: cstring)        ---
	@(link_name="read_history")
	_read_history            :: proc(filename: cstring)    -> c.int ---
	@(link_name="write_history")
	_write_history           :: proc(filename: cstring)    -> c.int ---
}
