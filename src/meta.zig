const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// A wrapper over `ArrayList([]const u8)` signaling that the strings are owned
/// and should be freed by us.
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

/// Clone a string.
pub fn dup(allocator: Allocator, buf: []const u8) ![]const u8 {
	const result = try allocator.alloc(u8, buf.len);
	@memcpy(result, buf);
	return result;
}

/// Like `std.mem.eql` but for strings and shorter.
pub fn eql(a: []const u8, b: []const u8) bool {
	return std.mem.eql(u8, a, b);
}

/// Compares `a` with a concatenation of all parts of `b`.
pub fn eql_concat(a: []const u8, b: []const []const u8) bool {
	var offset: usize = 0;
	for (b) |part| {
		if (!eql(a[offset..offset + part.len], part)) return false;
		offset += part.len;
	}
	return a.len == offset;
}

/// Like `std.mem.startsWith` but for strings and shorter.
pub fn startswith(haystack: []const u8, needle: []const u8) bool {
	return std.mem.startsWith(u8, haystack, needle);
}

var stdout_buf: [2048]u8 = undefined;
var stderr_buf: [1024]u8 = undefined;
var stdout = std.fs.File.stdout().writer(&stdout_buf);
var stderr = std.fs.File.stderr().writer(&stderr_buf);

/// Buffered stdout printing.
pub fn print(comptime fmt: []const u8, args: anytype) void {
	stdout.interface.print(fmt, args) catch {};
}

/// Buffered stderr printing, with a trailing newline.
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
