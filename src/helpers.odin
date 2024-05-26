package editline

import "base:runtime"
import "core:c"
import "core:c/libc"
import "core:mem"
import "core:strings"

global_callback_context: runtime.Context

@(private)
global_list_possib_proc: List_Possib_Proc
@(private)
global_complete_proc: Complete_Proc


List_Possib_Proc :: #type proc "odin" (word: string) -> []string

Complete_Proc    :: #type proc "odin" (partial: string) -> (result: string, ok: bool)


ctl    :: #force_inline proc "contextless" (x: c.int) -> c.int { return x & 0x1F }
isctl  :: #force_inline proc "contextless" (x: c.int) -> bool  { return x > 0 && x < cast(c.int)' '}
unctl  :: #force_inline proc "contextless" (x: c.int) -> c.int { return x + 64 }
meta   :: #force_inline proc "contextless" (x: c.int) -> c.int { return x | 0x80 }
ismeta :: #force_inline proc "contextless" (x: c.int) -> c.int { return x & 0x80 }
unmeta :: #force_inline proc "contextless" (x: c.int) -> c.int { return x & 0x7F }

print_columns :: proc(words: []string) {
	c_words := make([]cstring, len(words), context.temp_allocator)

	#no_bounds_check for word, i in words {
		c_words[i] = strings.clone_to_cstring(word, context.temp_allocator)
	}

	_print_columns(cast(c.int)len(words), &c_words[0])
}

// The string returned by this proc must be deleted by the user.
complete :: proc(token: string) -> (match: string, matches: int) {
	c_matches: c.int
	c_token := strings.clone_to_cstring(token, context.temp_allocator)
	c_match := _complete(c_token, &c_matches)
	matches = cast(int)c_matches
	match = strings.clone_from_cstring(c_match)
	libc.free(cast(rawptr)c_match)
	return
}

initialize :: proc(init_ctx := context) {
	global_callback_context = init_ctx

	// editline v1.17.1 has a sort of off-by-one bug with `el_hist_size`.
	// Addressed in editline PR #67
	hist_size += 1

	_initialize()
}

uninitialize :: proc() {
	_uninitialize()

	hist_size -= 1

	global_callback_context = {}
}

// The slice and the individual strings within this slice returned by this proc
// must be deleted by the user.
list_possib :: proc(token: string) -> (result: []string) {
	av: [^]cstring

	c_token := strings.clone_to_cstring(token, context.temp_allocator)
	ac := _list_possib(c_token, &av)

	result = make([]string, ac)

	#no_bounds_check for i in 0 ..< ac {
		result[i] = strings.clone_from_cstring(av[i])
		libc.free(cast(rawptr)av[i])
	}

	libc.free(cast(rawptr)av)
	return
}

insert_text :: proc(text: string) -> int {
	c_text := strings.clone_to_cstring(text, context.temp_allocator)
	return cast(int)_insert_text(c_text)
}

// Odin-style wrapper for `set_complete_func`.
//
// The internals of this proc do not delete the result returned to it by the
// user, in the event that it is given a static string, so it's best to use
// `context.temp_allocator` or handle cleanup elsewhere.
set_complete_proc :: proc(p: Complete_Proc) {
	assert(global_callback_context != {}, "editline must be initialized with an Odin context first")

	if p == nil {
		global_complete_proc = nil
		set_complete_func(nil)
		return
	}

	if global_complete_proc == nil {
		// Setup the C bridge only once.
		set_complete_func(proc "c" (partial: cstring, n: ^c.int) -> cstring {
			context = global_callback_context

			odin_partial := strings.clone_from_cstring(partial)
			odin_result, ok := global_complete_proc(odin_partial)
			delete(odin_partial)

			if !ok {
				n^ = 0
				return nil
			}

			n^ = 1

			// Explicitly use libc allocation, as editline will free what we
			// pass to it.
			cs := cast([^]c.char)libc.calloc(1 + len(odin_result), size_of(c.char))
			mem.copy_non_overlapping(cs, raw_data(odin_result), len(odin_result))
			cs[len(odin_result) - 1] = 0
			return cast(cstring)cs
		})
	}

	// Odin has no concept of lambda-bound variables, so a global variable will
	// do just fine.
	global_complete_proc = p
}

set_complete :: proc {
	set_complete_func,
	set_complete_proc,
}

// Odin-style wrapper for `set_list_possib_func`.
//
// The internals of this proc do not delete the results returned to it by the
// user, in the event that it is given a slice to static strings, so it's best
// to use `context.temp_allocator` or handle cleanup elsewhere.
set_list_possib_proc :: proc(p: List_Possib_Proc) {
	assert(global_callback_context != {}, "editline must be initialized with an Odin context first")

	if p == nil {
		global_list_possib_proc = nil
		set_list_possib_func(nil)
		return
	}

	if global_list_possib_proc == nil {
		// Setup the C bridge only once.
		set_list_possib_func(proc "c" (word: cstring, results: ^[^]cstring) -> c.int {
			context = global_callback_context

			odin_word := strings.clone_from_cstring(word)
			odin_results := global_list_possib_proc(odin_word)
			delete(odin_word)

			if len(odin_results) == 0 {
				results^ = nil
				return 0
			}

			results^ = cast([^]cstring)libc.calloc(len(odin_results), size_of(cstring))
			for result, i in odin_results {
				// Explicitly use libc allocation, as editline will free what we
				// pass to it.
				cs := cast([^]c.char)libc.calloc(1 + len(result), size_of(c.char))
				mem.copy_non_overlapping(cs, raw_data(result), len(result))
				cs[len(result) - 1] = 0
				results[i] = cast(cstring)cs
			}

			return cast(c.int)len(odin_results)
		})
	}

	// Odin has no concept of lambda-bound variables, so a global variable will
	// do just fine.
	global_list_possib_proc = p
}

set_list_possib :: proc {
	set_list_possib_func,
	set_list_possib_proc,
}

// The string returned by this proc must be deleted by the user, if `ok` is true.
readline :: proc(prompt: cstring = "? ") -> (line: string, ok: bool) {
	c_line := _readline(prompt)
	if c_line == nil {
		return "", false
	}
	line = strings.clone_from_cstring(c_line)
	libc.free(cast(rawptr)c_line)
	return line, true
}

add_history :: proc(line: string) {
	c_line := strings.clone_to_cstring(line, context.temp_allocator)
	_add_history(c_line)
}

read_history :: proc(filename: string) {
	c_filename := strings.clone_to_cstring(filename, context.temp_allocator)
	_read_history(c_filename)
}

write_history :: proc(filename: string) {
	c_filename := strings.clone_to_cstring(filename, context.temp_allocator)
	_write_history(c_filename)
}
