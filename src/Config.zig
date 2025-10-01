const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Parsed = std.json.Parsed;

const Self = @This();

cat_path: ?[]const u8 = null,
editor: ?[]const u8 = null,
package_manager: []const u8,
install_arg: []const u8,
uninstall_arg: []const u8,
cat_syntax: ?[]const u8 = null,
inline_comment_syntax: ?[]const u8 = null,
no_arg_action: ?[]const u8 = null,
default_cats: ?[]const []const u8 = null,
remove_empty_cats: ?bool = null,

pub const ConfigParseResult = struct {
	parsed_config: Parsed(Self),
	cat_path_is_owned: bool,

	pub fn init(allocator: Allocator, config_path: []const u8) !ConfigParseResult {
		const pakt_conf: []u8 = std.fs.cwd().readFileAlloc(
			allocator,
			config_path,
			std.math.maxInt(u16)
		) catch |err| {
			switch (err) {
				std.fs.File.OpenError.FileNotFound =>
					meta.errln("Config file at {s} not found!", .{config_path}),
				else => std.debug.print("Couldn't open config file!\n", .{})
			}
			return err;
		};
		defer allocator.free(pakt_conf);

		var parsed: Parsed(Self) = std.json.parseFromSlice(
			Self,
			allocator, pakt_conf, .{ .allocate = .alloc_always }
		) catch |err| {
			switch (err) {
				error.UnexpectedToken =>
					meta.errln("Failed to parse config! Unexpected token!", .{}),
				else => meta.errln(
					\\Failed to parse config!
					\\It was not a syntax error for sure but idk what else.
					, .{}
				)
			}
			return err;
		};
		const cat_path_is_owned = try parsed.value.set_default_values(allocator);
		return .{
			.parsed_config = parsed,
			.cat_path_is_owned = cat_path_is_owned
		};
	}

	pub fn deinit(self: *ConfigParseResult, allocator: Allocator) void {
		if (self.cat_path_is_owned) allocator.free(self.parsed_config.value.cat_path.?);
		self.parsed_config.deinit();
	}
};

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

	var it = std.mem.tokenizeScalar(u8, self.no_arg_action.?, ' ');
	while (it.next()) |arg| try argv.append(allocator, arg);

	var child = std.process.Child.init(argv.items, allocator);
	_ = try child.spawnAndWait();
}

fn set_default_values(self: *Self, allocator: Allocator) !bool {
	const result = self.cat_path == null;

	self.cat_path = self.cat_path orelse blk: {
		const share = std.process.getEnvVarOwned(allocator, "XDG_DATA_HOME") catch {
			const home = std.process.getEnvVarOwned(allocator, "HOME") catch {
				meta.errln(
					\\Failed to determite the path of the home directory!
					\\Something's really wrong!
					, .{}
				);
				return error.Generic;
			};
			defer allocator.free(home);

			break :blk try std.mem.concat(allocator, u8, &.{home, "/.local/share/pakt"});
		};
		defer allocator.free(share);
		break :blk try std.mem.concat(allocator, u8, &.{share, "/pakt"});
	};
	self.editor = self.editor                               orelse "nano";
	self.cat_syntax = self.cat_syntax                       orelse "+";
	self.inline_comment_syntax = self.inline_comment_syntax orelse ":";
	self.no_arg_action = self.no_arg_action                 orelse "pakt h";
	self.default_cats = self.default_cats                   orelse &.{};
	self.remove_empty_cats = self.remove_empty_cats         orelse true;

	return result;
}
