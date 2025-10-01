// TODO FINAL COMMENT ALL
// TODO FINAL TEST
// json valid but incomplete

// TODO implement optional json keys

const std = @import("std");
const meta = @import("meta.zig");
const subcommands = @import("subcommands.zig");

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

	const args = std.process.argsAlloc(allocator) catch return 1;
	defer std.process.argsFree(allocator, args);

	if (args.len == 1) {
		config.value.call_no_arg_action(allocator) catch return 1;
		return 0;
	}

	const subcommand = args[1];
	const eql = meta.eql;
	return if (eql(subcommand, "install") or eql(subcommand, "i"))
		subcommands.install(allocator, &config.value, args)
	else if (eql(subcommand, "uninstall") or eql(subcommand, "u"))
		subcommands.uninstall(allocator, &config.value, args)
	else if (eql(subcommand, "dry-install") or eql(subcommand, "di"))
		subcommands.dry_install(allocator, &config.value, args)
	else if (eql(subcommand, "dry-uninstall") or eql(subcommand, "du"))
		subcommands.dry_uninstall(allocator, &config.value, args)
	else if (eql(subcommand, "list") or eql(subcommand, "l"))
		subcommands.list(allocator, &config.value, args)
	else if (eql(subcommand, "edit") or eql(subcommand, "e"))
		subcommands.edit(allocator, &config.value, args)
	else if (eql(subcommand, "native") or eql(subcommand, "n"))
		subcommands.native(allocator, &config.value, args)
	else if (eql(subcommand, "help") or eql(subcommand, "h")) {
		subcommands.help(config_path);
		return 0;
	} else {
		meta.errln(
			"Invalid subcommand {s}!\nSee 'pakt help' for available options!",
			.{subcommand}
		);
		return 1;
	};
}
