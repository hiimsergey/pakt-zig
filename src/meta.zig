const std = @import("std");

pub fn eql(lhs: []const u8, rhs: []const u8) bool {
	return std.mem.eql(u8, lhs, rhs);
}

pub fn eql_concat(lhs: []const u8, rhs: []const []const u8) bool {
	var offset: usize = 0;
	for (rhs) |r| {
		if (!eql(lhs[offset..offset + r.len], r)) return false;
		offset += r.len;
	}
	return lhs.len == offset;
}

pub fn startswith(lhs: []const u8, rhs: []const u8) bool {
	return std.mem.startsWith(u8, lhs, rhs);
}

pub fn fail(comptime fmt: []const u8, args: anytype) void {
	// TODO
	std.debug.print("\x1b[31m" ++ fmt ++ "\n", args);
}
