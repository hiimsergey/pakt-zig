const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const Transaction = @import("Transaction.zig");

/// Install packages, write them into categories and/or give them inline comments.
pub fn install(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(gpa, 4);
	defer cmd.deinit(gpa);
	try cmd.appendSlice(gpa, config.package_manager);
	try cmd.appendSlice(gpa, config.install_args);

	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(gpa, args, &catman, config, &cmd);
	defer transaction.deinit(gpa);

	var child = std.process.Child.init(cmd.items, gpa);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) {
		meta.errln(
			"Package manager operation didn't succeed, thus no categorizing happens.",
			.{}
		);
		return error.Generic;
	}

	// The categorizing in question
	try transaction.write(&catman, config);
}

/// Uninstall packages and/or remove them from categories.
pub fn uninstall(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(gpa, 4);
	defer cmd.deinit(gpa);
	try cmd.appendSlice(gpa, config.package_manager);
	try cmd.appendSlice(gpa, config.uninstall_args);

	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(gpa, args, &catman, config, &cmd);
	defer transaction.deinit(gpa);

	var child = std.process.Child.init(cmd.items, gpa);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) {
		meta.errln(
			"Package manager operation didn't succeed, thus no decategorizing happens.",
			.{}
		);
		return error.Generic;
	}

	// The decategorizing in question
	try transaction.delete(&catman, config);
}

/// Bulk-install packages from category files or custom files.
pub fn syncInstall(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len == 2) {
		meta.errln(
			"Missing category names/file paths!\nSee 'pakt help' for correct usage!",
			.{}
		);
		return error.Generic;
	}

	var cmd = try ArrayList([]const u8).initCapacity(gpa, 4);
	defer cmd.deinit(gpa);
	try cmd.appendSlice(gpa, config.package_manager);
	try cmd.appendSlice(gpa, config.install_args);

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try ArrayList([]const u8).initCapacity(gpa, 2);
	defer file_list.deinit(gpa);
	try catman.writeFileList(gpa, args[2..], config, &file_list);

	for (file_list.items) |path| {
		var catfile = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
		defer catfile.close();

		var buf: [1024]u8 = undefined;
		var reader = catfile.reader(&buf);

		while (reader.interface.takeDelimiter('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse
					break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			try cmd.append(gpa, uncommented);
		}
	}

	var child = std.process.Child.init(cmd.items, gpa);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

pub fn syncUninstall(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len == 2) {
		meta.errln(
			"Missing category names/file paths!\nSee 'pakt help' for correct usage!",
			.{}
		);
		return error.Generic;
	}

	var cmd = try ArrayList([]const u8).initCapacity(gpa, 4);
	defer cmd.deinit(gpa);
	try cmd.appendSlice(gpa, config.package_manager);
	try cmd.appendSlice(gpa, config.uninstall_args);

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try ArrayList([]const u8).initCapacity(gpa, 2);
	defer file_list.deinit(gpa);
	try catman.writeFileList(gpa, args[2..], config, &file_list);

	for (file_list.items) |path| {
		var catfile = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
		defer catfile.close();

		var buf: [1024]u8 = undefined;
		var reader = catfile.reader(&buf);

		while (reader.interface.takeDelimiter('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			try cmd.append(gpa, uncommented);
		}
	}

	var child = std.process.Child.init(cmd.items, gpa);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

/// Add packages to categorizes without installing them.
pub fn dryInstall(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(gpa, args, &catman, config, null);
	defer transaction.deinit(gpa);

	// The categorizing in question
	try transaction.write(&catman, config);
}

/// Remove packages from categorizes without uninstalling them.
pub fn dryUninstall(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(gpa, args, &catman, config, null);
	defer transaction.deinit(gpa);

	// The decategorizing in question
	try transaction.delete(&catman, config);
}

/// List all created categories. The optinal argument is the separator between
/// the package names.
pub fn list(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len > 3) {
		meta.errln("Invalid args!\nSee 'pakt help' for correct usage!", .{});
		return error.Generic;
	}
	const separator: []const u8 = if (args.len == 2) "  " else args[2];

	var catman = try Categories.init(config);
	defer catman.deinit();

	var cat_list = try ArrayList([]const u8).initCapacity(gpa, 8);
	defer cat_list.deinit(gpa);
	try catman.appendAllCatNames(gpa, &cat_list);

	for (cat_list.items[0..cat_list.items.len - 1]) |item|
		meta.print("{s}{s}", .{item, separator});
	meta.print("{s}\n", .{cat_list.items[cat_list.items.len - 1]});
}

/// List the package names written in the given categories or custom files,
/// without comments.
pub fn cat(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len == 2) {
		meta.errln(
			"Missing category names/file paths!\nSee 'pakt help' for correct usage!",
			.{}
		);
		return error.Generic;
	}

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try ArrayList([]const u8).initCapacity(gpa, 2);
	defer file_list.deinit(gpa);
	try catman.writeFileList(gpa, args[2..], config, &file_list);

	for (file_list.items) |path| {
		var file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
			meta.errln("Failed to open the file '{s}'!", .{path});
			return err;
		};
		defer file.close();

		var buf: [1024]u8 = undefined;
		var reader = file.reader(&buf);

		while (reader.interface.takeDelimiter('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			if (uncommented.len > 0) meta.print("{s}\n", .{uncommented});
		}
	}
}

/// List the names of the categories containing at least one of the given package names.
pub fn find(_: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len < 3) {
		meta.errln("Missing package names!\nSee 'pakt help' for correct usage!", .{});
		return error.Generic;
	}

	var found_something = false;

	var catman = try Categories.init(config);
	defer catman.deinit();

	var buf: [1024]u8 = undefined;
	var it = catman.dir.iterate();

	cat: while (try it.next()) |entry| {
		var catfile = try catman.openCatfile(entry.name);
		defer catfile.close();

		var reader = catfile.reader(&buf);
		while (reader.interface.takeDelimiter('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i =
					std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			for (args[2..]) |pkg| if (meta.eql(uncommented, pkg)) {
				found_something = true;
				meta.print("{s}\n", .{entry.name});
				continue :cat;
			};
		}
	}

	// The return status should be 1 if nothing was found, similar to GNU find.
	if (!found_something) return error.Generic;
}

/// Open category files or custom ones in your editor of choice.
pub fn edit(gpa: Allocator, config: *Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(gpa, 3);
	defer cmd.deinit(gpa);

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try ArrayList([]const u8).initCapacity(gpa, 2);
	defer file_list.deinit(gpa);
	try catman.writeFileList(gpa, args[2..], config, &file_list);

	try cmd.append(gpa, config.editor.?);
	try cmd.appendSlice(gpa, file_list.items);

	var child = std.process.Child.init(cmd.items, gpa);
	const term = child.spawnAndWait() catch |err| {
		if (err == error.FileNotFound)
			meta.errln("Unkown editor: '{s}'!", .{config.editor.?});
		return err;
	};
	if (term.Exited != 0) return error.Generic;
}

/// Delete one or more category files.
pub fn purge(_: Allocator, config: *const Config, args: []const [:0]u8) !void {
	var stdin_buf: [128]u8 = undefined;
	var stdin = std.fs.File.stdin().reader(&stdin_buf);

	for (args[2..]) |arg| {
		if (!meta.startswith(arg, config.cat_syntax.?)) {
			meta.errln("Regular files like '{s}' are not supported!", .{arg});
			return error.Generic;
		}
		meta.print(" {s}", .{arg});
	}
	meta.print(
		"\nAre you sure you want to delete these categories? Type 'yes' to proceed: ",
		.{}
	);
	meta.outflush();

	const response = try stdin.interface.takeDelimiterExclusive('\n');
	if (!meta.eql(response, "yes")) return error.Generic;

	var catman = try Categories.init(config);
	defer catman.deinit();

	var err: anyerror!void = {};
	for (args[2..]) |arg| catman.dir.deleteFile(arg[config.cat_syntax.?.len..])
	catch |e| {
		meta.errln("Failed to delete {s}!", .{arg});
		err = e;
	};
	return err;
}

/// Perform a regular package manager operation without Pakt interpreting anything.
pub fn native(gpa: Allocator, config: *const Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(gpa, 3);
	defer cmd.deinit(gpa);

	try cmd.appendSlice(gpa, config.package_manager);
	try cmd.appendSlice(gpa, args[2..]);

	var child = std.process.Child.init(cmd.items, gpa);
	const term = child.spawnAndWait() catch {
		meta.err("Failed to spawn the command '", .{});
		for (cmd.items[0..cmd.items.len - 1]) |item| meta.err("{s}", .{item});
		meta.errln("{s}'!", .{cmd.items[cmd.items.len - 1]});

		return error.Generic;
	};
	if (term.Exited != 0) return error.Generic;
}

/// Self-explanatory, I guess.
pub fn help(config_path: []const u8) void {
	meta.print(@embedFile("help.txt"), .{config_path});
}
