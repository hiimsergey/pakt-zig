const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn list_all(list: ArrayList([]const u8), path: []const u8) !void {
	var cat_dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
	defer cat_dir.close();

	var it = cat_dir.iterate();
	while (try it.next()) |entry| list.append(entry.name);
}
