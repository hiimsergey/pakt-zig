const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn list_all(
	allocator: Allocator,
	list: ArrayList([]const u8),
	path: []const u8
) !void {
	var cat_dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
	defer cat_dir.close();

	var it = cat_dir.iterate();
	// TODO NOW DEBUG this line. idk what to do tbh
	while (try it.next()) |entry| try list.append(allocator, entry.name);
}
