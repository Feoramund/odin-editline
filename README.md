# odin-editline

This is a binding to the [editline](https://github.com/troglobit/editline) library for the Odin programming language.
Editline is an alternative to GNU readline, not to be confused with [libedit](https://www.thrysoee.dk/editline/).

## Example

```odin
package main

import "core:fmt"
import editline "src"

main :: proc() {
	editline.hist_size = 20

	editline.initialize()
	defer editline.uninitialize()

	editline.read_history("history.txt")

	for line in editline.readline() {
		fmt.printfln("You said: %q", line)

		delete(line)
	}

	editline.write_history("history.txt")
}
```

## Notes

`editline` shipped with an API prefixed by `el_` for editline-specific
functionality and `rl_` for the readline compatibility layer. As there were no
collisions between either set, all prefixes have been removed in this package's
API.

Where it made sense to do so, helper procedures were written to support Odin
strings over C strings, but where it was more likely that the argument wasn't
going to change very often (`readline`'s prompt argument, for example) or
`editline` did not internally make a copy of the string, the argument type was
kept as `cstring`, under the assumption that its memory management would be
best handled by the user.

The `initialize` helper also patches over an off-by-one bug in editline v1.17.1
by adding 1 to `el_hist_size` before calling the C `initialize`.
The bug is addressed in [this PR](https://github.com/troglobit/editline/pull/67).

### Helpers

- `initialize` and `uninitialize` handle the underlying Odin context for certain wrappers.
- `print_columns` simplifies having to work with multi-pointers.
- `complete` takes and returns an Odin string.
- `list_possib` handles multi-pointers.
- `insert_text`
- `set_list_possib_proc` augments `set_list_possib_func`.
- `set_complete_proc` augments `set_complete_func`.
- `readline` returns an Odin string and can be used iteratively.
- `add_history`
- `read_history`
- `write_history`

The underlying C functions are still accessible by prepending `_` to the name.
