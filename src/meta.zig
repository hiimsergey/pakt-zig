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

pub fn startswith(haystack: []const u8, needle: []const u8) bool {
	return std.mem.startsWith(u8, haystack, needle);
}

var stderr_buf: [1024]u8 = undefined;
var stderr = std.fs.File.stderr().writer(&stderr_buf);

pub fn errln(comptime fmt: []const u8, args: anytype) void {
	stderr.interface.print("\x1b[31m" ++ fmt ++ "\n", args) catch {};
}

/// Flush stderr.
pub fn flush() void {
	stderr.interface.flush() catch {};
}
