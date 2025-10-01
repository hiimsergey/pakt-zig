//! A struct containing a list of `PackageData`s describing an entire command's Pakt
//! transaction and a pool of all chunks of category args.
//! You could say this is the heart of transaction-specific arg parsing.

const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Categories = @import("Categories.zig");
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
	args: []const [:0]u8,
	catman: *const Categories,
	config: *Config,
	cmd: ?*ArrayList([]const u8)
) !Self {
	if (args.len < 3) {
		meta.errln("Missing package names!\nSee 'pakt help' for correct usage!", .{});
		return error.ExpectedArgs;
	}

	var result = Self{
		.data = try ArrayList(PackageData).initCapacity(allocator, 2),
		.cat_pool = try ArrayList([]const u8).initCapacity(allocator, 2)
	};

	var expecting_comment = false;
	var pkgs = ISlice{ .from = 0, .to = 0 };
	var cats = ISlice{ .from = 0, .to = 0 };

	for (args[2..]) |arg| {
		// Handle incoming comment
		if (expecting_comment) {
			result.data.items[result.data.items.len - 1].comment = arg;
			expecting_comment = false;

		// Wildcard token (like ++)
		} else if (meta.eql_concat(arg, &.{ config.cat_syntax, config.cat_syntax })) {
			try catman.append_all_cat_names(allocator, &result.cat_pool);
			cats.to = result.cat_pool.items.len;

		// Category token (like +)
		} else if (meta.startswith(arg, config.cat_syntax)) {
			const cat_owned = try allocator.alloc(u8, arg.len - config.cat_syntax.len);
			@memcpy(cat_owned, arg[config.cat_syntax.len..]);
			try result.cat_pool.append(allocator, cat_owned);
			cats.to += 1;

		// Comment marker (like :)
		} else if (meta.eql(arg, config.inline_comment_syntax)) {
			expecting_comment = true;

		// Non-Pakt flag
		} else if (meta.startswith(arg, "-")) {
			if (cmd) |c| try c.append(allocator, arg);

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
			if (cmd) |c| try c.append(allocator, arg);
		}
	}

	if (expecting_comment) {
		meta.errln(
			"Missing comment after the '{s}'!\nSee 'pakt help' for correct usage!",
			.{config.inline_comment_syntax}
		);
		return error.ExpectedComment;
	}

	try result.update_temporary(&pkgs, &cats);
	return result;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
	self.data.deinit(allocator);
	for (self.cat_pool.items) |cat| allocator.free(cat);
	self.cat_pool.deinit(allocator);
}

pub fn write(self: *Self, catman: *const Categories, config: *Config) !void {
	for (self.data.items) |pkgdata| {
		for (pkgdata.cats.slice(self.cat_pool.items)) |cat| {
			var catfile = try catman.open_catfile(cat);
			defer catfile.close();
			try write_package(pkgdata.name, &catfile, pkgdata.comment);
		}
		for (config.default_cats) |cat| {
			var catfile = try catman.open_catfile(cat);
			defer catfile.close();
			try write_package(pkgdata.name, &catfile, pkgdata.comment);
		}
	}
}

pub fn delete(self: *Self, catman: *const Categories) !void {
	for (self.data.items) |pkgdata| {
		for (pkgdata.cats.slice(self.cat_pool.items)) |cat| {
			var catfile = try catman.open_catfile(cat);
			defer catfile.close();
			try delete_package(pkgdata.name, &catfile);
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
	else _ = try writer.interface.print("{s}\n", .{pkg});

	try writer.interface.flush();
}

fn delete_package(pkg: []const u8, file: *std.fs.File) !void {
	var wbuf: [1024]u8 = undefined;
	var rbuf: [1024]u8 = undefined;
	var writer = file.writer(&wbuf);
	var reader = file.reader(&rbuf);

	while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
		const uncommented = std.mem.trim(u8, blk: {
			const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
			break :blk line[0..hash_i];
		}, " ");
		if (!meta.eql(uncommented, pkg)) _ = try writer.interface.print("{s}\n", .{line});
	}

	try writer.interface.flush();
	try file.setEndPos(writer.pos);
}
