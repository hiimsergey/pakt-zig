const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Config = @import("Config.zig");

pub fn open_catfile(allocator: Allocator, name: []const u8, config: *Config) !File {
	const catfile_path =
		try std.mem.concat(allocator, u8, &.{ config.cat_path, "/", name });
	defer allocator.free(catfile_path);

	return try std.fs.createFileAbsolute(
		catfile_path,
		.{ .read = true, .truncate = false }
	);
}

pub fn list_all(
	allocator: Allocator,
	cat_pool: *ArrayList([]const u8),
	config: *Config
) !void {
	var cat_dir = try std.fs.openDirAbsolute(config.cat_path, .{ .iterate = true });
	defer cat_dir.close();

	var it = cat_dir.iterate();
	while (try it.next()) |entry| try cat_pool.append(allocator, entry.name);
}
