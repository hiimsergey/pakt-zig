// TODO NOW error mesages for most misinputs
// TODO NOW replace nano with $EDITOR or nano
// TODO FINAL document inline comments
// in the README too
// TODO document every config key in the README
// TODO FINAL CONSIDER moving this repo to mminl

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

	var parse_result = Config.ConfigParseResult.init(allocator, config_path) catch
		return 1;
	defer parse_result.deinit(allocator);

	const args = std.process.argsAlloc(allocator) catch return 1;
	defer std.process.argsFree(allocator, args);

	if (args.len == 1) {
		parse_result.parsed_config.value.call_no_arg_action(allocator) catch return 1;
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
		*const fn (Allocator, *Config, []const [:0]u8) anyerror!void
	};
	for ([_]Description{
		.{ "install",        "i",  sc.install        },
		.{ "uninstall",      "u",  sc.uninstall      },
		.{ "sync-install",   "si", sc.sync_install   },
		.{ "sync-uninstall", "su", sc.sync_uninstall },
		.{ "dry-install",    "di", sc.dry_install    },
		.{ "dry-uninstall",  "du", sc.dry_uninstall  },
		.{ "list",           "l",  sc.list           },
		.{ "cat",            "c",  sc.cat            },
		.{ "find",           "f",  sc.find           },
		.{ "edit",           "e",  sc.edit           },
		.{ "purge",          "p",  sc.purge          },
		.{ "native",         "n",  sc.native         }
	}) |subcmd| {
		if (!meta.eql(arg1, subcmd.@"0") and !meta.eql(arg1, subcmd.@"1")) continue;
		subcmd.@"2"(allocator, &parse_result.parsed_config.value, args) catch return 1;
		break;
	} else {
		meta.errln(
			"Invalid subcommand '{s}'!\nSee 'pakt help' for available options!",
			.{arg1}
		);
		return 2;
	}

	return 0;
}
