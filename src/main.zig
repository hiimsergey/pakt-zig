// TODO FINAL TEST
// json valid but incomplete

// TODO NOW implement optional json keys

const std = @import("std");
const commands = @import("commands.zig");
const meta = @import("meta.zig");

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

	defer meta.flush();

	const config_path = Config.get_config_path(allocator) catch return 1;
	defer allocator.free(config_path);

	var config: Parsed(Config) = Config.parse(allocator, config_path) catch return 1;
	defer config.deinit();

	var args = std.process.args();
	_ = args.skip(); // skip "pakt"

	const subcommand = args.next() orelse {
		config.value.call_no_arg_action(allocator) catch return 1;
		return 0;
	};

	const eql = meta.eql;
	return if (eql(subcommand, "install") or eql(subcommand, "i"))
		commands.install(allocator, &config.value, &args)
	else if (eql(subcommand, "uninstall") or eql(subcommand, "u"))
		commands.uninstall(allocator, &config.value, &args)
	else if (eql(subcommand, "native") or eql(subcommand, "n"))
		commands.native(allocator, &config.value, &args)
	else if (eql(subcommand, "help") or eql(subcommand, "h")) {
		commands.help(config_path);
		return 0;
	} else {
		meta.fail(
			"Invalid subcommand {s}!\nSee 'pakt help' for available options!",
			.{subcommand}
		);
		return 1;
	};
}
