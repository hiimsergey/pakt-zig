//! Manager struct for the category files directory.

const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Config = @import("Config.zig");

const Self = @This();

dir: std.fs.Dir,

pub fn init(config: *Config) !Self {
	return .{
		.dir = try std.fs.openDirAbsolute(config.cat_path, .{ .iterate = true })
	};
}

pub fn deinit(self: *Self) void {
	self.dir.close();
}

pub fn open_catfile(self: *const Self, name: []const u8) !File {
	return try self.dir.createFile(name, .{ .read = true, .truncate = false });
}

pub fn append_all_cats(
	self: *const Self,
	allocator: Allocator,
	cat_pool: *ArrayList([]const u8)
) !void {
	var it = self.dir.iterate();
	while (try it.next()) |entry| {
		const entry_owned = try allocator.alloc(u8, entry.name.len);
		@memcpy(entry_owned, entry.name);
		try cat_pool.append(allocator, entry_owned);
	}
}
