const std = @import("std");
const categories = @import("categories.zig");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArgIterator = std.process.ArgIterator;
const Config = @import("Config.zig");

/// Description of a single package, the categories it goes into and its inline comment
const PackageData = struct {
	name: []const u8,
	cats: [][]const u8,
	comment: ?[]const u8,
};

/// A struct containing a list of `PackageData`s describing an entire command's Pakt
/// transaction and a pool of all chunks of category args.
pub const Transaction = struct {
	data: ArrayList(PackageData),
	cat_pool: ArrayList([]const u8),

	pub fn init(
		allocator: Allocator,
		args: *ArgIterator,
		config: *Config,
		cmd: *ArrayList([]const u8)
	) !Transaction {
		var result = Transaction{
			.data = try ArrayList(PackageData).initCapacity(allocator, 2),
			.cat_pool = try ArrayList([]const u8).initCapacity(allocator, 2)
		};

		var no_args = true;
		var expecting_comment = false;

		var pkgs = try ArrayList([]const u8).initCapacity(allocator, 2);
		defer pkgs.deinit(allocator);

		var cats: [][]const u8 = &.{};
		var comment: ?[]const u8 = null;

		while (args.next()) |arg| {
			no_args = false;

			if (expecting_comment) {
				comment = arg;
				expecting_comment = false;

			} else if (meta.eql_concat(arg, &.{ config.cat_syntax, config.cat_syntax })) {
				const old_len = result.cat_pool.items.len;
				try categories.list_all(allocator, &result.cat_pool, config);
				cats = result.cat_pool.items[old_len..result.cat_pool.items.len];

			} else if (meta.startswith(arg, config.cat_syntax)) {
				try result.cat_pool.append(allocator, arg[config.cat_syntax.len..]);
				const offset: usize =
					@intFromPtr(cats.ptr) - @intFromPtr(result.cat_pool.items.ptr);
				cats = result.cat_pool.items[offset..offset + cats.len + 1];

			} else if (meta.eql(arg, ":")) {
				expecting_comment = true;

			} else if (meta.startswith(arg, "-")) {
				try cmd.append(allocator, arg);

			} else {
				// A package comes after a category declaration, meaning we have
				// to reset the temporary descriptors.
				if (cats.len > 0) {
					for (pkgs.items) |pkg| try result.data.append(allocator, PackageData{
						.name = pkg,
						.cats = cats,
						.comment = null
					});
					result.data.items[result.data.items.len - 1].comment = comment;

					pkgs.clearRetainingCapacity();
					cats = &.{};
					comment = null;
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
		self.data.deinit(allocator);
		self.cat_pool.deinit(allocator);
	}

	pub fn write(self: *Transaction, allocator: Allocator, config: *Config) !void {
		for (self.data.items) |pkgdata| {
			for (pkgdata.cats) |cat|
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

		var buf: [1024]u8 = undefined; // TODO NOW
		var reader = catfile.reader(&buf);
		std.debug.print("\n\n", .{});
		while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
			std.debug.print("line: {s}\n", .{line});
			// TODO NOW
			_ = name;
			_ = comment;
		}
	}
};
