const std = @import("std");
const logic = @import("logic.zig");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const AllocatorWrapper = @import("allocator.zig").AllocatorWrapper;
const ArrayList = std.ArrayList;
const ArgIterator = std.process.ArgIterator;
const Config = @import("config.zig").Config;
const Parsed = std.json.Parsed;

inline fn install(allocator: Allocator, config: *Config, args: *ArgIterator) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 3) catch return 1;
	defer cmd.deinit(allocator);
	cmd.appendSlice(allocator, &.{ config.package_manager, config.install_arg }) catch
		return 1;

	const transaction = logic.Transaction.init(allocator, args, config, cmd) catch
		return 1;
	defer transaction.deinit(allocator);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = try child.spawnAndWait();
	if (term.Signal != 0)
		meta.fail("Package manager operation failed, thus no categorizing happens.", .{});

	transaction.write(allocator, config); // TODO

	return term.Signal;
}

inline fn help() void {
	std.debug.print("TODO help", .{});
}

pub fn main() u8 {
	var aw = AllocatorWrapper.init();
	defer aw.deinit();

	const allocator = aw.allocator();

	var config: Parsed(Config) = Config.parse(allocator) catch return 1;
	defer config.deinit();

	var args = std.process.args();
	_ = args.skip(); // skip "pakt"

	const subcommand = args.next() orelse {
		config.value.call_no_arg_action(allocator) catch return 1;
		return 0;
	};

	const eql = meta.eql;
	return if (eql(subcommand, "install") or eql(subcommand, "i"))
		install(allocator, &config.value, &args)
	else if (eql(subcommand, "help") or eql(subcommand, "h")) {
		help();
		return 0;
	} else {
		meta.fail(
			"Invalid subcommand {s}!\nSee 'pakt help' for available options!",
			.{ subcommand }
		);
		return 1;
	};
}

// TODO HANDLE default cats

// TODO FINAL TEST
// json valid but incomplete
