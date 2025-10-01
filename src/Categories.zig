//! Manager struct for the category files directory.

const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Config = @import("Config.zig");

const Self = @This();

const StringListOwned = struct {
	data: ArrayList([]const u8),

	pub fn deinit(self: *StringListOwned, allocator: Allocator) void {
		for (self.data.items) |item| allocator.free(item);
		self.data.deinit(allocator);
	}
};

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

pub fn append_all_cat_names(
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

pub fn get_file_list(
	self: *const Self,
	allocator: Allocator,
	args: []const [:0]u8,
	config: *Config
) !StringListOwned {
	var result = StringListOwned{
		.data = try ArrayList([]const u8).initCapacity(allocator, args.len)
	};

	for (args) |arg| {
		if (meta.eql_concat(arg, &.{config.cat_syntax, config.cat_syntax})) {
			result.data.clearRetainingCapacity();
			try self.append_all_cat_paths(allocator, config, &result.data);
		} else if (meta.startswith(arg, config.cat_syntax)) {
			const cat_name = arg[config.cat_syntax.len..];
			const cat_path =
				try std.mem.concat(allocator, u8, &.{config.cat_path, "/", cat_name});
			try result.data.append(allocator, cat_path);
		} else {
			const arg_owned = try allocator.alloc(u8, arg.len);
			@memcpy(arg_owned, arg);
			try result.data.append(allocator, arg_owned);
		}
	}

	return result;
}

fn append_all_cat_paths(
	self: *const Self,
	allocator: Allocator,
	config: *Config,
	cat_pool: *ArrayList([]const u8)
) !void {
	var it = self.dir.iterate();
	while (try it.next()) |entry| {
		const path = try std.mem.concat(allocator, u8, &.{config.cat_path, "/", entry.name});
		try cat_pool.append(allocator, path);
	}
}
