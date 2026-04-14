# pakt-zig
A recreational rewrite of our Bash script [Pakt](https://github.com/mminl-de/pakt) in the glorious Zig language.

## Default config
```json
{
	"package_manager": /* no default */,
	"install_args": /* no default */,
	"uninstall_args": /* no default */,
	"cat_path": null,
	"editor": "nano",
	"cat_syntax": "+",
	"inline_comment_syntax": ":",
	"no_arg_action": ["pakt", "help"],
	"default_cats": [],
	"remove_empty_cats": true
}
```

| Option                | Type        | Description                                                                  | Note                                                                                    |
| --                    | --          | --                                                                           | --                                                                                      |
| package_manager       | string list | Underlying package manager                                                   | Needs to be given!                                                                      |
| install_args          | string list | Package manager arguments used by `pakt install`                             | Needs to be given!                                                                      |
| uninstall_args        | string list | Package manager arguments used by `pakt uninstall`                           | Needs to be given!                                                                      |
| cat_path              | string      | Where category files are stored in plain text                                | If value is null, pakt uses either `$XDG_DATA_HOME/pakt/` or `~/.local/share/pakt/`     |
| editor                | string      | Which editor is called if you want to edit category files from pakt manually |                                                                                         |
| cat_syntax            | string      | Characters used as prefix for category names in arguments                    |                                                                                         |
| inline_comment_syntax | string      | Characters marking that next argument is package comment                     |                                                                                         |
| no_arg_action         | string list | Command triggered by running `pakt`                                          |                                                                                         |
| default_cats          | string list | Categories that every new package is put into implicitly                     |                                                                                         |
| remove_empty_cats     | bool        | Whether empty category files should be removed                               |                                                                                         |
