const std = @import("std");
const meta = @import("meta.zig");
const sc = @import("subcommands.zig");

const Allocator = std.mem.Allocator;
const AllocatorWrapper = @import("AllocatorWrapper.zig");
const Config = @import("Config.zig");

pub fn main() u8 {
	var aw = AllocatorWrapper.init();
	defer aw.deinit();
	const child_allocator = aw.allocator();

	var arena = std.heap.ArenaAllocator.init(child_allocator);
	defer arena.deinit();
	const gpa = arena.allocator();

	defer {
		meta.outflush();
		meta.errflush();
	}

	const config_path = Config.getConfigPath(gpa) catch return 1;

	var parse_result = Config.ParseResult.init(gpa, config_path) catch return 1;
	// TODO NOW defer parse_result.deinit(gpa);

	const args = std.process.argsAlloc(gpa) catch return 1;
	// TODO NOW defer std.process.argsFree(gpa, args);

	if (args.len == 1) {
		parse_result.parsed_config.value.callNoArgAction(gpa) catch return 1;
		return 0;
	}

	if (meta.eql(args[1], "help") or meta.eql(args[1], "h")) {
		sc.help(config_path);
		return 0;
	}

	for ([_]struct {
		[]const u8,
		[]const u8,
		*const fn (Allocator, *Config, []const [:0]u8) anyerror!void
	}{
		.{ "install",        "i",  sc.install       },
		.{ "uninstall",      "u",  sc.uninstall     },
		.{ "sync-install",   "si", sc.syncInstall   },
		.{ "sync-uninstall", "su", sc.syncUninstall },
		.{ "dry-install",    "di", sc.dryInstall    },
		.{ "dry-uninstall",  "du", sc.dryUninstall  },
		.{ "list",           "l",  sc.list          },
		.{ "cat",            "c",  sc.cat           },
		.{ "find",           "f",  sc.find          },
		.{ "edit",           "e",  sc.edit          },
		.{ "purge",          "p",  sc.purge         },
		.{ "native",         "n",  sc.native        }
	}) |subcmd| {
		if (!meta.eql(args[1], subcmd.@"0") and !meta.eql(args[1], subcmd.@"1")) continue;
		subcmd.@"2"(gpa, &parse_result.parsed_config.value, args) catch return 1;
		break;
	} else {
		meta.errln(
			"Invalid subcommand '{s}'!\nSee 'pakt help' for available options!",
			.{args[1]}
		);
		return 2;
	}

	return 0;
}
