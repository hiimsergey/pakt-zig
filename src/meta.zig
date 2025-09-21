const std = @import("std");

const Allocator = std.mem.Allocator;
const Config = @import("config.zig").Config;
const Parsed = std.json.Parsed;

pub inline fn eql(lhs: []const u8, rhs: []const u8) bool {
	return std.mem.eql(u8, lhs, rhs);
}

pub inline fn fail(comptime fmt: []const u8, args: anytype) void {
	// TODO
	std.debug.print(fmt ++ "\n", args);
}

pub fn call_no_arg_action(allocator: Allocator, config: *Parsed(Config)) !void {
	var argv = try std.ArrayList([]const u8).initCapacity(allocator, 2);
	defer argv.deinit(allocator);

	var it = std.mem.tokenizeScalar(u8, config.value.no_arg_action, ' ');
	while (it.next()) |arg| try argv.append(allocator, arg);

	var child = std.process.Child.init(argv.items, allocator);
	_ = try child.spawnAndWait();
}
