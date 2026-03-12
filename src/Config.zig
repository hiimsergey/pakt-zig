const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const Parsed = std.json.Parsed;
const Self = @This();

cat_path: ?[]const u8 = null,
editor: ?[]const u8 = "nano",
package_manager: []const []const u8,
install_args: []const []const u8,
uninstall_args: []const []const u8,
cat_syntax: ?[]const u8 = "+",
inline_comment_syntax: ?[]const u8 = ":",
no_arg_action: ?[]const []const u8 = &.{"pakt", "help"},
default_cats: ?[]const []const u8 = &.{},
remove_empty_cats: ?bool = true,

const config_reference_text =
	"See https://github.com/hiimsergey/pakt-zig for a correct config.";

/// Parse the JSON file at `config_path` and instantiate this result struct.
pub fn parse(gpa: Allocator, config_path: []const u8) !Parsed(Self) {
	const pakt_conf: []u8 = std.fs.cwd().readFileAlloc(
		gpa,
		config_path,
		std.math.maxInt(u16)
	) catch |err| {
		switch (err) {
			std.fs.File.OpenError.FileNotFound => {
				meta.errln("Config file at {s} not found!", .{config_path});
				meta.errln(config_reference_text, .{});
			},
			else => meta.errln("Couldn't open config file!", .{})
		}
		return err;
	};

	var result: Parsed(Self) = std.json.parseFromSlice(
		Self,
		gpa, pakt_conf, .{ .allocate = .alloc_always }
	) catch |err| {
		switch (err) {
			error.UnexpectedToken => {
				meta.errln("Failed to parse config! Unexpected token!", .{});
				meta.errln(config_reference_text, .{});
			},
			else => meta.errln(
				\\Failed to parse config!
				\\It was not a syntax error for sure but idk what else.
				, .{}
			)
		}
		return err;
	};
	try result.value.setDefaultCatPath(gpa);
	return result;
}

/// Determines the absolute path of the pakt.json config by reading the $PAKT_CONF_PATH
/// or $XDG_CONFIG_HOME environment variables.
pub fn getConfigPath(gpa: Allocator) ![]const u8 {
	return std.process.getEnvVarOwned(gpa, "PAKT_CONF_PATH") catch {
		const config_path = std.process.getEnvVarOwned(gpa, "XDG_CONFIG_HOME")
		catch blk: {
			const home = try std.process.getEnvVarOwned(gpa, "HOME");
			break :blk try std.mem.concat(gpa, u8, &.{home, "/.config"});
		};

		return try std.mem.concat(gpa, u8, &.{config_path, "/pakt.json"});
	};
}

/// Run the user-defined no_arg_action.
pub fn callNoArgAction(self: *Self, gpa: Allocator) !void {
	var child = std.process.Child.init(self.no_arg_action.?, gpa);
	const term = child.spawnAndWait() catch {
		const items = self.no_arg_action.?;

		meta.errprint("Failed to run the no arg action '", .{});
		for (items[0..items.len - 1]) |item| meta.errprint("{s} ", .{item});
		meta.errln("{s}'!", .{items[items.len - 1]});

		return error.Generic;
	};
	if (term.Exited != 0) return error.Generic;
}

/// Write the hard-coded default value for the cat_path option, if it's null.
fn setDefaultCatPath(self: *Self, gpa: Allocator) !void {
	if (self.cat_path != null) return;

	const share = std.process.getEnvVarOwned(gpa, "XDG_DATA_HOME") catch {
		const home = std.process.getEnvVarOwned(gpa, "HOME") catch {
			meta.errln(
				\\Failed to determite the path of the home directory!
				\\Something's really wrong!
				, .{}
			);
			return error.Generic;
		};

		self.cat_path = try std.mem.concat(gpa, u8, &.{home, "/.local/share/pakt"});
		return;
	};

	self.cat_path = try std.mem.concat(gpa, u8, &.{share, "/pakt"});
}
