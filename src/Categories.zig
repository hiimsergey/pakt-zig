//! Manager struct for the category files directory.

const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Config = @import("Config.zig");
const StringListOwned = meta.StringListOwned;

const Self = @This();

dir: std.fs.Dir,

/// Instantiate this class by opening the category path.
pub fn init(config: *const Config) !Self {
	return .{
		.dir = std.fs.openDirAbsolute(config.cat_path.?, .{ .iterate = true })
		catch |err| {
			meta.errln("Failed to open the category dir!", .{});
			return err;
		}
	};
}

/// Close the category path.
pub fn deinit(self: *Self) void {
	self.dir.close();
}

/// Given a category name, open or create the respective file.
pub fn open_catfile(self: *const Self, name: []const u8) !File {
	return self.dir.createFile(name, .{ .read = true, .truncate = false }) catch |err| {
		meta.errln("Failed to open the file of the category '{s}'!", .{name});
		return err;
	};
}

/// Given a pointer to a `StringListOwned`, extend it with every category's name.
pub fn append_all_cat_names(
	self: *const Self,
	allocator: Allocator,
	cat_list: *StringListOwned
) !void {
	var it = self.dir.iterate();
	while (try it.next()) |entry|
		try cat_list.data.append(allocator, try meta.dup(allocator, entry.name));
}

/// Given a pointer to a `StringListOwned`, extend it with absolute paths of
/// files references by `args`. If an arg starts with the cat syntax (+ by default),
/// then the rest is interpreted as the basename of a category file. Otherwise,
/// the arg is read as-is as a file path.
/// Just like usual, double cat syntax (++ by default) is interpreted as all
/// category files' paths.
pub fn write_file_list(
	self: *const Self,
	allocator: Allocator,
	args: []const [:0]u8,
	config: *Config,
	file_list: *StringListOwned
) !void {
	for (args) |arg| {
		if (meta.eql_concat(arg, &.{config.cat_syntax.?, config.cat_syntax.?})) {
			var it = self.dir.iterate();
			while (try it.next()) |entry| {
				const path = try std.mem.concat(
					allocator,
					u8,
					&.{config.cat_path.?, "/", entry.name}
				);
				try file_list.data.append(allocator, path);
			}
		} else if (meta.startswith(arg, config.cat_syntax.?)) {
			const cat_name = arg[config.cat_syntax.?.len..];
			const cat_path = try std.mem.concat(
				allocator,
				u8,
				&.{config.cat_path.?, "/", cat_name}
			);
			try file_list.data.append(allocator, cat_path);
		} else {
			try file_list.data.append(allocator, try meta.dup(allocator, arg));
		}
	}
}
