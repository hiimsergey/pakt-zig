# pakt-zig
A recreational rewrite of our Bash script [Pakt](https://github.com/mminl-de/pakt) in the glorious Zig language.

## Default config
```json
{
	"cat_path": null,
	"editor": "nano",
	"package_manager": !!!,
	"install_args": !!!,
	"uninstall_args": !!!,
	"cat_syntax": "+",
	"inline_comment_syntax": ":",
	"no_arg_action": ["pakt", "help"],
	"default_cats": [],
	"remove_empty_cats": true
}
```

| Option | Type | Description | Note |
| -- | -- | -- | -- |
| cat_path | string | where the category files are stored in plain text | If the value is null, pakt uses either `$XDG_DATA_HOME/pakt/` or `~/.local/share/pakt/` |
| editor | string | Which editor is called if you want to edit category files from pakt manually | |
| package_manager | string list | Underlying package manager | Needs to be given! |
| install_args | string list | Package manager arguments used by `pakt install` | Needs to be given! |
| uninstall_args | string list | Package manager arguments used by `pakt uninstall` | Needs to be given! |
| cat_syntax | string | Characters used as prefix for category names in arguments | |
| inline_comment_syntax | string | Characters marking that the next argument is a package comment | |
| no_arg_action | string list | Command triggered by running `pakt` | |
| default_cats | string list | Categories that every new package is put into implicitly | |
| remove_empty_cats | bool | Whether empty category files should be removed | |
