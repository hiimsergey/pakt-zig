const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Parsed = std.json.Parsed;

const Self = @This();

cat_path: []const u8,
editor: []const u8,
package_manager: []const u8,
install_arg: []const u8,
uninstall_arg: []const u8,
cat_syntax: []const u8,
no_arg_action: []const u8,
default_cats: []const []const u8,
remove_empty_cats: bool,

pub fn parse(allocator: Allocator, config_path: []const u8) !Parsed(Self) {
	const pakt_conf: []u8 = std.fs.cwd().readFileAlloc(
		allocator,
		config_path,
		std.math.maxInt(u16)
	) catch |err| {
		switch (err) {
			std.fs.File.OpenError.FileNotFound =>
				meta.fail("Config file at {s} not found!", .{config_path}),
			else => std.debug.print("TODO otherwise {s}\n", .{@errorName(err)})
		}
		return err;
	};
	defer allocator.free(pakt_conf);

	return std.json.parseFromSlice(
		Self,
		allocator, pakt_conf, .{ .allocate = .alloc_always }
	) catch |err| {
		switch (err) {
			error.UnexpectedToken =>
				meta.fail("Failed to parse config! Unexpected token!", .{}),
			else => meta.fail(
				\\Failed to parse config!
				\\It was not a syntax error for sure but other than that idk what.
				, .{}
			)
		}
		return err;
	};
}

pub fn get_config_path(allocator: Allocator) ![]const u8 {
	return std.process.getEnvVarOwned(allocator, "PAKT_CONF_PATH") catch {
		const config_path = std.process.getEnvVarOwned(allocator, "XDG_CONFIG_HOME")
		catch blk: {
			const home = try std.process.getEnvVarOwned(allocator, "HOME");
			defer allocator.free(home);
			break :blk try std.mem.concat(allocator, u8, &.{ home, "/.config" });
		};
		defer allocator.free(config_path);

		return try std.mem.concat(allocator, u8, &.{ config_path, "/pakt.json" });
	};
}

pub fn call_no_arg_action(self: *Self, allocator: Allocator) !void {
	var argv = try std.ArrayList([]const u8).initCapacity(allocator, 2);
	defer argv.deinit(allocator);

	var it = std.mem.tokenizeScalar(u8, self.no_arg_action, ' ');
	while (it.next()) |arg| try argv.append(allocator, arg);

	var child = std.process.Child.init(argv.items, allocator);
	_ = try child.spawnAndWait();
}
