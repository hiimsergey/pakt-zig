const std = @import("std");
const Allocator = std.mem.Allocator;
const AllocatorWrapper = @import("allocator.zig").AllocatorWrapper;

const Config = struct {
	editor: []const u8,
	package_manager: []const u8,
	install_arg: []const u8,
	uninstall_arg: []const u8,
	no_arg_action: []const u8,
	remove_empty_cats: bool,

	pub fn parse(allocator: Allocator) !std.json.Parsed(Config) {
		const config_path = try Config.get_config_path(allocator);
		defer allocator.free(config_path);

		var pakt_conf = try std.fs.openFileAbsolute(config_path, .{ .mode = .read_only });
		defer pakt_conf.close();

		return try std.json.parseFromSlice(
			Config,
			allocator, pakt_conf, .{ .allocate = .alloc_always }
		);
	}

	fn get_config_path(allocator: Allocator) []const u8 {
		return std.process.getEnvVarOwned("PAKT_CONF_PATH") catch {
			const config_path = std.process.getEnvVarOwned("XDG_CONFIG_HOME") catch blk: {
				const home = std.process.getEnvVarOwned("HOME") catch {};
				defer allocator.free(home);
				break :blk std.mem.concat(u8, &.{ home, "/.config" });
			};
			defer allocator.free(config_path);

			return std.mem.concat(u8, &.{ config_path, "/pakt/pakt.json" });
		};
	}
};

pub fn main() u8 {
	var aw = AllocatorWrapper.init();
	defer aw.deinit();

	const allocator = aw.allocator();

	const config = Config.parse(allocator) catch return 1;
	defer config.deinit();
}
