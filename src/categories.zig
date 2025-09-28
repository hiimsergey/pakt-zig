const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Config = @import("Config.zig");

// TODO signature
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
