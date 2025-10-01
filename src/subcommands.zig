const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const StringListOwned = meta.StringListOwned;
const Transaction = @import("Transaction.zig");

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
			const uncommented_owned = try allocator.alloc(u8, uncommented.len);
			@memcpy(uncommented_owned, uncommented);

			try cmd.data.append(allocator, uncommented_owned);
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
			const uncommented_owned = try allocator.alloc(u8, uncommented.len);
			@memcpy(uncommented_owned, uncommented);

			try cmd.data.append(allocator, uncommented_owned);
		}
	}

	var child = std.process.Child.init(cmd.data.items, allocator);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

pub fn dry_install(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(allocator, args, &catman, config, null);
	defer transaction.deinit(allocator);

	// The categorizing in question
	try transaction.write(&catman, config);
}

pub fn dry_uninstall(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var catman = try Categories.init(config);
	defer catman.deinit();

	var transaction = try Transaction.init(allocator, args, &catman, config, null);
	defer transaction.deinit(allocator);

	// The decategorizing in question
	try transaction.delete(&catman, config);
}

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

	if (!found_something) return error.Generic;
}

pub fn edit(allocator: Allocator, config: *Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(allocator, 3);
	defer cmd.deinit(allocator);

	var catman = try Categories.init(config);
	defer catman.deinit();

	var file_list = try StringListOwned.init_capacity(allocator, 2);
	defer file_list.deinit(allocator);
	try catman.write_file_list(allocator, args[2..], config, &file_list);

	try cmd.append(allocator, config.editor);
	try cmd.appendSlice(allocator, file_list.data.items);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

pub fn purge(_: Allocator, config: *const Config, args: []const [:0]u8) !void {
	var stdin_buf: [128]u8 = undefined;
	var stdin = std.fs.File.stdin().reader(&stdin_buf);

	for (args[2..]) |arg| meta.print(" +{s}", .{arg});
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
	for (args[2..]) |arg| catman.dir.deleteFile(arg) catch |e| {
		meta.errln("Failed to delete +{s}", .{arg});
		err = e;
	};
	return err orelse {};
}

pub fn native(allocator: Allocator, config: *const Config, args: []const [:0]u8) !void {
	var cmd = try ArrayList([]const u8).initCapacity(allocator, 3);
	defer cmd.deinit(allocator);

	try cmd.append(allocator, config.package_manager);
	try cmd.appendSlice(allocator, args[2..]);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = try child.spawnAndWait();
	if (term.Exited != 0) return error.Generic;
}

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
\\    v1.1.3  GPL-3.0  https://github.com/hiimsergey/pakt-zig
\\    Sergey Lavrent <https://github.com/hiimsergey>
\\
\\    Based on the pakt shell script:
\\        https://github.com/mminl-de/pakt
\\        Sergey Lavrent <https://github.com/hiimsergey>
\\        MrMineDe <https://github.com/mrminede>
\\
	, .{config_path});
}
