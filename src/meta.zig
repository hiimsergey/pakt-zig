const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const StringListOwned = struct {
	data: ArrayList([]const u8),

	pub fn init_capacity(allocator: Allocator, n: usize) !StringListOwned {
		return .{
			.data = try ArrayList([]const u8).initCapacity(allocator, n)
		};
	}

	pub fn deinit(self: *StringListOwned, allocator: Allocator) void {
		for (self.data.items) |item| allocator.free(item);
		self.data.deinit(allocator);
	}
};

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

var stdout_buf: [2048]u8 = undefined;
var stderr_buf: [1024]u8 = undefined;
var stdout = std.fs.File.stdout().writer(&stdout_buf);
var stderr = std.fs.File.stderr().writer(&stderr_buf);

pub fn print(comptime fmt: []const u8, args: anytype) void {
	stdout.interface.print(fmt, args) catch {};
}

pub fn errln(comptime fmt: []const u8, args: anytype) void {
	stderr.interface.print("\x1b[31m" ++ fmt ++ "\n", args) catch {};
}

/// Flush stdout.
pub fn outflush() void {
	stdout.interface.flush() catch {};
}

/// Flush stderr.
pub fn errflush() void {
	stderr.interface.flush() catch {};
}
