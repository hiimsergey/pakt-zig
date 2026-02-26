//! A struct containing a list of `PackageData`s describing an entire command's Pakt
//! transaction and a pool of all chunks of category args.
//! You could say this is the heart of transaction-specific arg parsing.

const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const StringListOwned = meta.StringListOwned;
const Self = @This();

data: ArrayList(PackageData),
cat_list: StringListOwned,

/// An index based slice description over an unrelated array. Unlike regular slices,
/// it doesn't get invalidated if an `ArrayList` gets appended to.
const ISlice = struct {
	from: usize,
	to: usize,

	/// Slice `buf` with `Self`'s bounds.
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

/// Read the other arguments and store which packages are assigned to which
/// categories. If `cmd` is non-null, then append arguments that belong to
/// the package manager command.
pub fn init(
	gpa: Allocator,
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
		.data = try ArrayList(PackageData).initCapacity(gpa, 2),
		.cat_list = try StringListOwned.initCapacity(gpa, 2)
	};

	var expecting_comment = false;
	var pkgs = ISlice{ .from = 0, .to = 0 };
	var cats = ISlice{ .from = 0, .to = 0 };

	for (args[2..]) |arg| {
		// Handle incoming comment
		if (expecting_comment) {
			result.data.items[result.data.items.len - 1].comment = arg;
			expecting_comment = false;
		}
		// Wildcard token (like ++)
		else if (meta.eqlConcat(arg, &.{ config.cat_syntax.?, config.cat_syntax.? })) {
			try catman.appendAllCatNames(gpa, &result.cat_list);
			cats.to = result.cat_list.data.items.len;
		}
		// Category token (like +)
		else if (meta.startswith(arg, config.cat_syntax.?)) {
			const cat_dupe = try gpa.dupe(u8, arg[config.cat_syntax.?.len..]);
			try result.cat_list.data.append(gpa, cat_dupe);
			cats.to += 1;
		}
		// Comment marker (like :)
		else if (meta.eql(arg, config.inline_comment_syntax.?)) {
			expecting_comment = true;
		}
		// Non-Pakt flag
		else if (meta.startswith(arg, "-")) {
			if (cmd) |c| try c.append(gpa, arg);
		}
		// Probably a package
		else {
			// A package comes after a category declaration, meaning we have
			// to reset the temporary descriptors.
			if (cats.to - cats.from > 0)
				try result.updateTemporary(&pkgs, &cats);
			try result.data.append(gpa, .{
				.name = arg,
				.cats = undefined,
				.comment = null
			});
			pkgs.to += 1;
			if (cmd) |c| try c.append(gpa, arg);
		}
	}

	if (expecting_comment) {
		meta.errln(
			"Missing comment after the '{s}'!\nSee 'pakt help' for correct usage!",
			.{config.inline_comment_syntax.?}
		);
		return error.ExpectedComment;
	}

	try result.updateTemporary(&pkgs, &cats);
	return result;
}

pub fn deinit(self: *Self, gpa: Allocator) void {
	self.data.deinit(gpa);
	self.cat_list.deinit(gpa);
}

/// Write the situation into the involved categories' files.
pub fn write(self: *Self, catman: *const Categories, config: *Config) !void {
	for (self.data.items) |pkgdata| {
		for (pkgdata.cats.slice(self.cat_list.data.items)) |cat| {
			var catfile = try catman.openCatfile(cat);
			defer catfile.close();
			try writePackage(&catfile, pkgdata.name, pkgdata.comment);
		}
		for (config.default_cats.?) |cat| {
			var catfile = try catman.openCatfile(cat);
			defer catfile.close();
			try writePackage(&catfile, pkgdata.name, pkgdata.comment);
		}
	}
}

/// Remove packages from the involved categories' files.
pub fn delete(self: *Self, catman: *const Categories, config: *Config) !void {
	for (self.data.items) |pkgdata| {
		for (pkgdata.cats.slice(self.cat_list.data.items)) |cat| {
			var catfile = try catman.openCatfile(cat);
			defer catfile.close();
			try deletePackage(pkgdata.name, &catfile);
			if (config.remove_empty_cats.? and try catfile.getEndPos() == 0)
				try catman.dir.deleteFile(cat);
		}
	}
}

/// Reset helper variables owned by `init()`.
fn updateTemporary(self: *Self, pkgs: *ISlice, cats: *ISlice) !void {
	for (pkgs.slice(self.data.items)) |*pkg| pkg.cats = cats.*;
	pkgs.* = .{ .from = self.data.items.len, .to = 0 };
	cats.* = .{ .from = self.cat_list.data.items.len, .to = 0 };
}

/// Write the package name and its inline comment into the given file.
fn writePackage(file: *std.fs.File, pkg: []const u8, comment: ?[]const u8) !void {
	var buf: [1024]u8 = undefined;

	// Check if package already exists in a category file
	var reader = file.reader(&buf);
	while (reader.interface.takeDelimiter('\n') catch null) |line| {
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

/// Remove the lines with the package name from the given file.
fn deletePackage(pkg: []const u8, file: *std.fs.File) !void {
	var wbuf: [1024]u8 = undefined;
	var rbuf: [1024]u8 = undefined;
	var writer = file.writer(&wbuf);
	var reader = file.reader(&rbuf);

	while (reader.interface.takeDelimiter('\n') catch null) |line| {
		const uncommented = std.mem.trim(u8, blk: {
			const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
			break :blk line[0..hash_i];
		}, " ");
		if (!meta.eql(uncommented, pkg)) _ = try writer.interface.print("{s}\n", .{line});
	}

	try writer.interface.flush();
	try file.setEndPos(writer.pos);
}
