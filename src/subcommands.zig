const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const StringListOwned = meta.StringListOwned;
const Transaction = @import("Transaction.zig");

/// Install packages, write them into categories and/or give them inline comments.
pub fn install(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(allocator, 4);
	defer cmd.deinit(allocator);
	try cmd.appendSlice(allocator, &.{config.package_manager, config.uninstall_arg});

	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(allocator, args, &catman, config, &cmd);
	defer transaction.deinit(allocator);

	var child = std.process.Child.init(cmd.items, allocator);
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
pub fn uninstall(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(allocator, 4);
	defer cmd.deinit(allocator);
	try cmd.appendSlice(allocator, &.{config.package_manager, config.uninstall_arg});

	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(allocator, args, &catman, config, &cmd);
	defer transaction.deinit(allocator);

	var child = std.process.Child.init(cmd.items, allocator);
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
pub fn sync_install(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len == 2) {
		meta.errln(
			"Missing category names/file paths!\nSee 'pakt help' for correct usage!",
			.{}
		);
		return error.Generic;
	}

	var cmd = try StringListOwned.init_capacity(allocator, 4);
	defer cmd.deinit(allocator);

	// We have to clone the strings because of the requirement of `StringListOwned`.
	try cmd.data.appendSlice(allocator, &.{
		try meta.dup(allocator, config.package_manager),
		try meta.dup(allocator, config.install_arg)
	});

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try StringListOwned.init_capacity(allocator, 2);
	defer file_list.deinit(allocator);
	try catman.write_file_list(allocator, args[2..], config, &file_list);

	for (file_list.data.items) |path| {
		var catfile = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
		defer catfile.close();

		var buf: [1024]u8 = undefined;
		var reader = catfile.reader(&buf);

		while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			try cmd.data.append(allocator, try meta.dup(allocator, uncommented));
		}
	}

	var child = std.process.Child.init(cmd.data.items, allocator);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

pub fn sync_uninstall(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len == 2) {
		meta.errln(
			"Missing category names/file paths!\nSee 'pakt help' for correct usage!",
			.{}
		);
		return error.Generic;
	}

	var cmd = try StringListOwned.init_capacity(allocator, 4);
	defer cmd.deinit(allocator);

	// We have to clone the strings because of the requirement of `StringListOwned`.
	try cmd.data.appendSlice(allocator, &.{
		try meta.dup(allocator, config.package_manager),
		try meta.dup(allocator, config.uninstall_arg)
	});

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try StringListOwned.init_capacity(allocator, 2);
	defer file_list.deinit(allocator);
	try catman.write_file_list(allocator, args[2..], config, &file_list);

	for (file_list.data.items) |path| {
		var catfile = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
		defer catfile.close();

		var buf: [1024]u8 = undefined;
		var reader = catfile.reader(&buf);

		while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			try cmd.data.append(allocator, try meta.dup(allocator, uncommented));
		}
	}

	var child = std.process.Child.init(cmd.data.items, allocator);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

/// Add packages to categorizes without installing them.
pub fn dry_install(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(allocator, args, &catman, config, null);
	defer transaction.deinit(allocator);

	// The categorizing in question
	try transaction.write(&catman, config);
}

/// Remove packages from categorizes without uninstalling them.
pub fn dry_uninstall(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(allocator, args, &catman, config, null);
	defer transaction.deinit(allocator);

	// The decategorizing in question
	try transaction.delete(&catman, config);
}

/// List all created categories. The optinal argument is the separator between
/// the package names.
pub fn list(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len > 3) {
		meta.errln("Invalid args!\nSee 'pakt help' for correct usage!", .{});
		return error.Generic;
	}
	const separator: []const u8 = if (args.len == 2) "  " else args[2];

	var catman = try Categories.init(config);
	defer catman.deinit();

	var cat_list = try StringListOwned.init_capacity(allocator, 8);
	defer cat_list.deinit(allocator);
	try catman.append_all_cat_names(allocator, &cat_list);

	const string = try std.mem.join(allocator, separator, cat_list.data.items);
	defer allocator.free(string);
	meta.print("{s}\n", .{string});
}

/// List the package names written in the given categories or custom files,
/// without comments.
pub fn cat(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	if (args.len == 2) {
		meta.errln(
			"Missing category names/file paths!\nSee 'pakt help' for correct usage!",
			.{}
		);
		return error.Generic;
	}

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try StringListOwned.init_capacity(allocator, 2);
	defer file_list.deinit(allocator);
	try catman.write_file_list(allocator, args[2..], config, &file_list);

	for (file_list.data.items) |path| {
		var file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
		defer file.close();

		var buf: [1024]u8 = undefined;
		var reader = file.reader(&buf);

		while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i = std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			meta.print("{s}\n", .{uncommented});
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
		var catfile = try catman.open_catfile(entry.name);
		defer catfile.close();

		var reader = catfile.reader(&buf);
		while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
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
pub fn edit(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(allocator, 3);
	defer cmd.deinit(allocator);

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try StringListOwned.init_capacity(allocator, 2);
	defer file_list.deinit(allocator);
	try catman.write_file_list(allocator, args[2..], config, &file_list);

	try cmd.append(allocator, config.editor.?);
	try cmd.appendSlice(allocator, file_list.data.items);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = child.spawnAndWait() catch |err| {
		if (err == error.FileNotFound)
			meta.errln("Unkown editor: '{s}'", .{config.editor.?});
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
			meta.errln("\nRegular files are like '{s}' are not supported!\n", .{arg});
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

	var err: ?anyerror = null;
	for (args[2..]) |arg| catman.dir.deleteFile(arg[config.cat_syntax.?.len..]) catch |e| {
		meta.errln("Failed to delete +{s}", .{arg});
		err = e;
	};
	return err orelse {};
}

/// Perform a regular package manager operation without Pakt interpreting anything.
pub fn native(allocator: Allocator, config: *const Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(allocator, 3);
	defer cmd.deinit(allocator);

	try cmd.append(allocator, config.package_manager);
	try cmd.appendSlice(allocator, args[2..]);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

/// Self-explanatory, I guess.
pub fn help(config_path: []const u8) void {
	meta.print(
\\pakt – a package manager wrapper with support for categorizing
\\
\\Usage:
\\    pakt                                          perform a user-defined arbitrary action
\\    pakt i(nstall)          (pkg [+cat ...])...   install packages
\\    pakt u(ninstall)        (pkg [+cat ...])...   uninstall packages
\\    pakt d(ry-)i(nstall)    (pkg [+cat ...])...   write packages into categories without
\\                                                    installing them
\\    pakt d(ry-)u(ninstall)  (pkg [+cat ...])...   remove packages from categories without
\\                                                    uninstalling them
\\    pakt s(ync-)i(nstall)   (file | +cat)...      install several packages from categories
\\                                                    or arbitrary files
\\    pakt s(ync-)u(ninstall) (file | +cat)...      uninstall several packages from categories
\\                                                    or arbitary files
\\    pakt l(ist)             (separator)           list all user-defined categories separated
\\                                                    separated by an optional string
\\    pakt c(at)              (file | +cat)...      list all packages in the given categories
\\    pakt f(ind)             pkg...                list categories the given packages are in
\\    pakt e(dit)             (file | +cat)...      edit category or arbitary files manually
\\    pakt p(urge)            +cat...               remove entire category files
\\    pakt n(ative)           pm-arg...             perform a regular package manager operation
\\    pakt h(elp)                                   print this message
\\
\\Configuration:
\\    {s}
\\
\\About:
\\    v2.0.0  GPL-3.0  https://github.com/hiimsergey/pakt-zig
\\    Sergey Lavrent <https://github.com/hiimsergey>
\\
\\A Zig rewrite of the POSIX shell script:    https://github.com/mminl-de/pakt
\\
	, .{config_path});
}
