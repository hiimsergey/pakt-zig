const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const AllocatorWrapper = @import("allocator.zig").AllocatorWrapper;
const Config = @import("config.zig").Config;
const Parsed = std.json.Parsed;

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
		meta.call_no_arg_action(allocator, &config) catch return 1;
		return 0;
	};

	const eql = meta.eql;
	if (eql(subcommand, "help") or eql(subcommand, "h")) {
		help();
		return 0;
	} else {
		meta.fail(
			"Invalid subcommand {s}!\nSee 'pakt help' for available options!",
			.{ subcommand }
		);
		return 1;
	}
}
