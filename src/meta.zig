const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// Like `std.mem.eql` but for strings and shorter.
pub fn eql(a: []const u8, b: []const u8) bool {
	return std.mem.eql(u8, a, b);
}

/// Compare `a` with a concatenation of all parts of `bs`.
pub fn eqlConcat(a: []const u8, bs: []const []const u8) bool {
	var offset: usize = 0;
	for (bs) |part| {
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

/// Buffered stderr printing.
pub fn err(comptime fmt: []const u8, args: anytype) void {
	stderr.interface.print("\x1b[31;1mpakt: ", .{}) catch {};
	stderr.interface.print(fmt, args) catch {};
}

/// Buffered stderr printing, with a trailing newline.
pub fn errln(comptime fmt: []const u8, args: anytype) void {
	stderr.interface.print("\x1b[31;1mpakt: ", .{}) catch {};
	stderr.interface.print(fmt ++ "\n", args) catch {};
}

/// Flush stdout.
pub fn outflush() void {
	stdout.interface.flush() catch {};
}

/// Flush stderr.
pub fn errflush() void {
	stderr.interface.flush() catch {};
}
