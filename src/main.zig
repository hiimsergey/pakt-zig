// TODO FINAL COMMENT ALL
// TODO FINAL TEST
// json valid but incomplete

// TODO implement optional json keys

const std = @import("std");
const meta = @import("meta.zig");
const sc = @import("subcommands.zig");

const Allocator = std.mem.Allocator;
const AllocatorWrapper = @import("allocator.zig").AllocatorWrapper;
const ArrayList = std.ArrayList;
const ArgIterator = std.process.ArgIterator;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const Parsed = std.json.Parsed;
const Transaction = @import("Transaction.zig");

pub fn main() u8 {
	var aw = AllocatorWrapper.init();
	defer aw.deinit();
	const allocator = aw.allocator();

	defer {
		meta.outflush();
		meta.errflush();
	}

	const config_path = Config.get_config_path(allocator) catch return 1;
	defer allocator.free(config_path);

	var parsed_config: Parsed(Config) =
		Config.parse(allocator, config_path) catch return 1;
	defer parsed_config.deinit();

	const args = std.process.argsAlloc(allocator) catch return 1;
	defer std.process.argsFree(allocator, args);

	if (args.len == 1) {
		parsed_config.value.call_no_arg_action(allocator) catch return 1;
		return 0;
	}
	const arg1 = args[1];

	if (meta.eql(arg1, "help") or meta.eql(arg1, "h")) {
		sc.help(config_path);
		return 0;
	}
	const Description = struct {
		[]const u8,
		[]const u8,
		*const fn (Allocator, *Config, []const [:0]u8) u8
	};
	const SUBCOMMAND_TABLE = [_]Description{
		.{ "install",       "i",  sc.install      },
		.{ "uninstall",     "u",  sc.uninstall    },
		.{ "sync-install",  "si", sc.sync_install },
		.{ "dry-install",   "di", sc.dry_install  },
		.{ "dry-uninstall", "du", sc.dry_install  },
		.{ "list",          "l",  sc.list         },
		.{ "cat",           "c",  sc.cat          },
		.{ "find",          "f",  sc.find         },
		.{ "edit",          "e",  sc.edit         },
		.{ "purge",         "p",  sc.purge        },
		.{ "native",        "n",  sc.native       }
	};

	for (SUBCOMMAND_TABLE) |subcmd| {
		if (meta.eql(arg1, subcmd.@"0") or meta.eql(arg1, subcmd.@"1"))
			return subcmd.@"2"(allocator, &parsed_config.value, args);
	} else {
		meta.errln(
			"Invalid subcommand '{s}'!\nSee 'pakt help' for available options!",
			.{arg1}
		);
		return 2;
	}
}
