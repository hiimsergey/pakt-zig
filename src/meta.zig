const std = @import("std");

const Allocator = std.mem.Allocator;
const Config = @import("config.zig").Config;
const Parsed = std.json.Parsed;

pub inline fn eql(lhs: []const u8, rhs: []const u8) bool {
	return std.mem.eql(u8, lhs, rhs);
}

pub fn eql_concat(lhs: []const u8, rhs: []const []const u8) bool {
	var rhs_len: usize = 0;
	for (rhs) |r| {
		if (!eql(lhs[rhs_len..r.len], r)) return false;
		rhs_len += r.len;
	}
	return lhs.len == rhs_len;
}

pub inline fn startswith(lhs: []const u8, rhs: []const u8) bool {
	return std.mem.startsWith(u8, lhs, rhs);
}

pub inline fn fail(comptime fmt: []const u8, args: anytype) void {
	// TODO
	std.debug.print(fmt ++ "\n", args);
}
