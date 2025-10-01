const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Parsed = std.json.Parsed;

const Self = @This();

cat_path: ?[]const u8 = null,
editor: ?[]const u8 = null,
package_manager: []const []const u8,
install_args: []const []const u8,
uninstall_args: []const []const u8,
cat_syntax: ?[]const u8 = null,
inline_comment_syntax: ?[]const u8 = null,
no_arg_action: ?[]const []const u8 = null,
default_cats: ?[]const []const u8 = null,
remove_empty_cats: ?bool = null,

/// A struct wrapping both the JSON parsing result and a flag about whether
/// to free a string option or not.
pub const ConfigParseResult = struct {
	parsed_config: Parsed(Self),
	cat_path_is_owned: bool,

	/// Parse the JSON file at `config_path` and instantiate this result struct.
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

		// Not every key needs to be present in the JSON file. The options just
		// get set to null. This function replaces them with a default value.
		const cat_path_is_owned = try parsed.value.set_default_values(allocator);
		return .{
			.parsed_config = parsed,
			.cat_path_is_owned = cat_path_is_owned
		};
	}

	/// Free a string option if it's owned by us and free the JSON parsing result.
	pub fn deinit(self: *ConfigParseResult, allocator: Allocator) void {
		if (self.cat_path_is_owned) allocator.free(self.parsed_config.value.cat_path.?);
		self.parsed_config.deinit();
	}
};

/// Determines the absolute path of the pakt.json config by reading the $PAKT_CONF_PATH
/// or $XDG_CONFIG_HOME environment variables.
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

/// Run the user-defined no_arg_action.
pub fn call_no_arg_action(self: *Self, allocator: Allocator) !void {
	var child = std.process.Child.init(self.no_arg_action.?, allocator);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

/// Write the hard-coded default value for every option with the value null.
/// Return whether the `cat_path` option is owned by this instance or not.
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
	self.no_arg_action = self.no_arg_action                 orelse &.{"pakt", "help"};
	self.default_cats = self.default_cats                   orelse &.{};
	self.remove_empty_cats = self.remove_empty_cats         orelse true;

	return result;
}
