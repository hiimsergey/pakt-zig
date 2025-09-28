//! A struct containing a list of `PackageData`s describing an entire command's Pakt
//! transaction and a pool of all chunks of category args.

const std = @import("std");
const categories = @import("categories.zig");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArgIterator = std.process.ArgIterator;
const Config = @import("Config.zig");

const ISlice = struct { from: usize, to: usize };

/// Description of a single package, the categories it goes into and its inline comment
const PackageData = struct {
	name: []const u8,
	cats: ISlice,
	comment: ?[]const u8,
};

const Self = @This();

data: ArrayList(PackageData),
cat_pool: ArrayList([]const u8),

pub fn init(
	allocator: Allocator,
	args: *ArgIterator,
	config: *Config,
	cmd: *ArrayList([]const u8)
) !Self {
	var result = Self{
		.data = try ArrayList(PackageData).initCapacity(allocator, 2),
		.cat_pool = try ArrayList([]const u8).initCapacity(allocator, 2)
	};

	var no_args = true;
	var expecting_comment = false;

	var pkgs = try ArrayList([]const u8).initCapacity(allocator, 2);
	defer pkgs.deinit(allocator);

	var cats = ISlice{ .from = 0, .to = 0 };
	var comment: ?[]const u8 = null;

	while (args.next()) |arg| {
		no_args = false;

		if (expecting_comment) {
			comment = arg;
			expecting_comment = false;

		} else if (meta.eql_concat(arg, &.{ config.cat_syntax, config.cat_syntax })) {
			cats.from = result.cat_pool.items.len;
			try categories.list_all(allocator, &result.cat_pool, config);
			cats.to = result.cat_pool.items.len;

		} else if (meta.startswith(arg, config.cat_syntax)) {
			try result.cat_pool.append(allocator, arg[config.cat_syntax.len..]);
			cats.to += 1;

		} else if (meta.eql(arg, ":")) {
			expecting_comment = true;

		} else if (meta.startswith(arg, "-")) {
			try cmd.append(allocator, arg);

		} else {
			// A package comes after a category declaration, meaning we have
			// to reset the temporary descriptors.
			if (cats.to - cats.from > 0)
				try result.update_temporary(allocator, &pkgs, &cats, &comment);
			try pkgs.append(allocator, arg);
			try cmd.append(allocator, arg);
		}
	}
	
	if (no_args) {
		meta.fail("Missing package names!\nSee 'pakt help' for correct usage!", .{});
		return error.ExpectedArgs;
	}

	try result.update_temporary(allocator, &pkgs, &cats, &comment);
	return result;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
	self.data.deinit(allocator);
	self.cat_pool.deinit(allocator);
}

pub fn write(self: *Self, allocator: Allocator, config: *Config) !void {
	for (self.data.items) |pkgdata| {
		std.debug.print("TODO pkg {s} with {d} categories\n", .{pkgdata.name, pkgdata.cats.to - pkgdata.cats.from});
		for (self.cat_pool.items[pkgdata.cats.from..pkgdata.cats.to]) |cat|
			try write_package(
				allocator,
				pkgdata.name, cat, pkgdata.comment,
				config.cat_path
			);
		for (config.default_cats) |cat|
			try write_package(
				allocator,
				pkgdata.name, cat, pkgdata.comment,
				config.cat_path
			);
	}
}

fn update_temporary(
	self: *Self,
	allocator: Allocator,
	pkgs: *ArrayList([]const u8),
	cats: *ISlice,
	comment: *?[]const u8
) !void {
	for (pkgs.items) |pkg| try self.data.append(allocator, .{
		.name = pkg,
		.cats = cats.*,
		.comment = null
	});
	self.data.items[self.data.items.len - 1].comment = comment.*;

	pkgs.clearRetainingCapacity();
	cats.* = .{ .from = 0, .to = 0 };
	comment.* = null;
}

fn write_package(
	allocator: Allocator,
	pkg: []const u8,
	category: []const u8,
	comment: ?[]const u8,
	cat_path: []const u8
) !void {
	const catfile_path =
		try std.mem.concat(allocator, u8, &.{ cat_path, "/", category });
	defer allocator.free(catfile_path);

	const catfile = try std.fs.createFileAbsolute(
		catfile_path,
		.{ .read = true, .truncate = false }
	);
	defer catfile.close();
	std.debug.print("TODO We opened the file {s}!\n", .{catfile_path});

	var buf: [1024]u8 = undefined;

	// Check if package already exists in a category file
	var reader = catfile.reader(&buf);
	while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
		const uncommented = std.mem.trim(u8, blk: {
			const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
			break :blk line[0..hash_i];
		}, " ");

		if (meta.eql(uncommented, pkg)) return;
	}

	// Write package (with comment, if existing) into category file.
	var writer = catfile.writer(&buf);
	if (comment) |com| {
		const content = try std.mem.concat(allocator, u8, &.{ pkg, " # ", com });
		_ = try writer.interface.write(content);
		allocator.free(content);
	} else {
		_ = try writer.interface.write(pkg);
	}

	try writer.interface.flush();
}
