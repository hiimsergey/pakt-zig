//! A struct containing a list of `PackageData`s describing an entire command's Pakt
//! transaction and a pool of all chunks of category args.

const std = @import("std");
const categories = @import("categories.zig");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArgIterator = std.process.ArgIterator;
const Config = @import("Config.zig");

/// An index based slice description over an unrelated array. Unlike regular slices,
/// it doesn't get invalidated if an `ArrayList` gets appended to.
const ISlice = struct {
	from: usize,
	to: usize,

	pub fn slice(self: *const ISlice, buf: anytype) @TypeOf(buf) {
		return buf[self.from..self.to];
	}
};

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

	var pkgs = ISlice{ .from = 0, .to = 0 };
	var cats = ISlice{ .from = 0, .to = 0 };

	while (args.next()) |arg| {
		no_args = false;

		// Handle incoming comment
		if (expecting_comment) {
			result.data.items[result.data.items.len - 1].comment = arg;
			expecting_comment = false;

		// Wildcard token (like ++)
		} else if (meta.eql_concat(arg, &.{ config.cat_syntax, config.cat_syntax })) {
			try categories.list_all(allocator, &result.cat_pool, config);
			cats.to = result.cat_pool.items.len;

		// Category token (like +)
		} else if (meta.startswith(arg, config.cat_syntax)) {
			try result.cat_pool.append(allocator, arg[config.cat_syntax.len..]);
			cats.to += 1;

		// Comment marker (:)
		} else if (meta.eql(arg, ":")) {
			expecting_comment = true;

		// Non-Pakt flag
		} else if (meta.startswith(arg, "-")) {
			try cmd.append(allocator, arg);

		// Probably a package
		} else {
			// A package comes after a category declaration, meaning we have
			// to reset the temporary descriptors.
			if (cats.to - cats.from > 0)
				try result.update_temporary(&pkgs, &cats);
			try result.data.append(allocator, .{
				.name = arg,
				.cats = undefined,
				.comment = null
			});
			pkgs.to += 1;
			try cmd.append(allocator, arg);
		}
	}
	
	if (no_args) {
		meta.fail("Missing package names!\nSee 'pakt help' for correct usage!", .{});
		return error.ExpectedArgs;
	}

	try result.update_temporary(&pkgs, &cats);
	return result;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
	self.data.deinit(allocator);
	self.cat_pool.deinit(allocator);
}

pub fn write(self: *Self, allocator: Allocator, config: *Config) !void {
	for (self.data.items) |pkgdata| {
		for (pkgdata.cats.slice(self.cat_pool.items)) |cat| {
			var catfile = try categories.open_catfile(allocator, cat, config);
			defer catfile.close();
			try write_package(pkgdata.name, &catfile, pkgdata.comment);
		}
		for (config.default_cats) |cat| {
			var catfile = try categories.open_catfile(allocator, cat, config);
			defer catfile.close();
			try write_package(pkgdata.name, &catfile, pkgdata.comment);
		}
	}
}

fn update_temporary(self: *Self, pkgs: *ISlice, cats: *ISlice) !void {
	for (pkgs.slice(self.data.items)) |*pkg| pkg.cats = cats.*;
	pkgs.* = .{ .from = self.data.items.len, .to = 0 };
	cats.* = .{ .from = self.cat_pool.items.len, .to = 0 };
}

fn write_package(pkg: []const u8, file: *std.fs.File, comment: ?[]const u8) !void {
	var buf: [1024]u8 = undefined;

	// Check if package already exists in a category file
	var reader = file.reader(&buf);
	while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
		const uncommented = std.mem.trim(u8, blk: {
			const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
			break :blk line[0..hash_i];
		}, " ");

		if (meta.eql(uncommented, pkg)) return;
	}

	// Write package (with comment, if existing) into category file.
	var writer = file.writer(&buf);
	try writer.seekTo(try file.getEndPos());
	if (comment) |com| _ = try writer.interface.print("{s} # {s}\n", .{pkg, com})
	else _ = try writer.interface.write(pkg);

	try writer.interface.flush();
}
