const std = @import("std");
const categories = @import("categories.zig");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArgIterator = std.process.ArgIterator;
const Config = @import("config.zig").Config;

pub const Transaction = struct {
	data: ArrayList(PackageData),

	pub fn init(
		allocator: Allocator,
		args: *ArgIterator,
		config: *Config,
		cmd: ArrayList([]const u8)
	) !Transaction {
		var result = Transaction{ .data = ArrayList(PackageData).initCapacity(allocator, 2) };

		var no_args = true;
		var expecting_comment = false;

		var pkgs = ArrayList([]const u8).initCapacity(allocator, 2);
		defer pkgs.deinit();

		var curpkg = PackageData.init(allocator);
		defer curpkg.deinit();

		while (args.next()) |arg| {
			no_args = false;

			if (expecting_comment) {
				curpkg.comment = arg;
				expecting_comment = false;
			} else if (meta.eql_concat(arg, &.{ config.cat_syntax, config.cat_syntax })) {
				try categories.list_all(curpkg.categories, config.cat_path);
			} else if (meta.startswith(arg, config.cat_syntax)) {
				try curpkg.categories.append(allocator, arg[config.cat_syntax.len..]);
				// TODO
			} else if (meta.eql(arg, ":")) {
				expecting_comment = true;
			} else if (meta.startswith(arg, "-")) {
				try cmd.append(allocator, arg);
			} else {
				if (curpkg.categories.items.len > 0) {
					for (pkgs) |pkg| {
						const pkgdata = try PackageData.init(allocator);
						pkgdata.name = pkg;
						pkgdata.categories = curpkg.categories;
						try result.data.append(allocator, pkgdata);
					}
					result.data.items[result.data.items.len - 1].comment = curpkg.comment;

					pkgs.clearRetainingCapacity();
					curpkg.categories = ArrayList([]const u8).initCapacity(allocator, 2);
					curpkg.comment = null;
				}
				try pkgs.append(allocator, arg);
				try cmd.append(allocator, arg);
			}
		}
		
		if (no_args) {
			meta.fail("Missing package names!\nSee 'pakt help' for correct usage!", .{});
			return error.ExpectedArgs;
		}
		return result;
	}

	pub fn deinit(self: *Transaction, allocator: Allocator) void {
		for (self.data.items) |item| item.categories.deinit(allocator);
		self.deinit();
	}

	pub fn write(self: *Transaction, allocator: Allocator, config: *Config) void {
		for (self.data) |pkgdata| {
			for (pkgdata.categories.items) |cat|
				try write_package(allocator, pkgdata.name, cat, pkgdata.comment, config.cat_path);
			for (config.default_cats.items) |cat|
				try write_package(allocator, pkgdata.name, cat, pkgdata.comment, config.cat_path);
		}
	}

	fn write_package(
		allocator: Allocator,
		name: []const u8,
		category: []const u8,
		comment: ?[]const u8,
		cat_path: []const u8
	) !void {
		const catfile_path =
			try std.mem.concat(allocator, u8, &.{ cat_path, "/", category });
		defer allocator.free(catfile_path);

		const catfile = try std.fs.openFileAbsolute(catfile_path, .{ .mode = .read_write });
		defer catfile.close();

		// TODO NOW
	}
};

const PackageData = struct {
	name: []const u8,
	categories: ArrayList([]const u8),
	comment: ?[]const u8,

	pub fn init(allocator: Allocator) !PackageData {
		var result = undefined;
		try result.categories.initCapacity(allocator, 2);
		return result;
	}

	pub fn deinit(self: *PackageData, allocator: Allocator) void {
		self.categories.deinit(allocator);
	}
};
