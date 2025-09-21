const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const Parsed = std.json.Parsed;

pub const Config = struct {
	editor: []const u8,
	package_manager: []const u8,
	install_arg: []const u8,
	uninstall_arg: []const u8,
	no_arg_action: []const u8,
	remove_empty_cats: bool,

	pub fn parse(allocator: Allocator) !Parsed(Config) {
		const config_path = try Config.get_config_path(allocator);
		defer allocator.free(config_path);

		const pakt_conf = std.fs.cwd().readFileAlloc(
			allocator,
			config_path,
			std.math.maxInt(u16)
		) catch |err| {
			switch (err) {
				std.fs.File.OpenError.FileNotFound =>
					meta.fail("Config file at {s} not found!", .{ config_path }),
				else => std.debug.print("TODO otherwise {s}\n", .{@errorName(err)})
			}
			return err;
		};
		defer allocator.free(pakt_conf);

		return try std.json.parseFromSlice(
			Config,
			allocator, pakt_conf, .{ .allocate = .alloc_always }
		);
	}

	fn get_config_path(allocator: Allocator) ![]const u8 {
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
};
