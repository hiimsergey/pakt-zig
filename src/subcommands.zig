const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const StringListOwned = meta.StringListOwned;
const Transaction = @import("Transaction.zig");

pub fn install(allocator: Allocator, config: *Config, args: []const [:0]u8) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 4) catch return 1;
	defer cmd.deinit(allocator);
	cmd.appendSlice(
		allocator,
		&.{config.package_manager, config.uninstall_arg}
	) catch return 1;

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var transaction =
		Transaction.init(allocator, args, &catman, config, &cmd) catch return 1;
	defer transaction.deinit(allocator);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = child.spawnAndWait() catch return 1;
	if (term.Exited != 0) {
		meta.errln(
			"Package manager operation didn't succeed, thus no categorizing happens.",
			.{}
		);
		return 1;
	}

	// The categorizing in question
	transaction.write(&catman, config) catch return 1;
	return 0;
}

pub fn uninstall(allocator: Allocator, config: *Config, args: []const [:0]u8) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 4) catch return 1;
	defer cmd.deinit(allocator);
	cmd.appendSlice(
		allocator,
		&.{config.package_manager, config.uninstall_arg}
	) catch return 1;

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var transaction =
		Transaction.init(allocator, args, &catman, config, &cmd) catch return 1;
	defer transaction.deinit(allocator);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = child.spawnAndWait() catch return 1;
	if (term.Exited != 0) {
		meta.errln(
			"Package manager operation didn't succeed, thus no decategorizing happens.",
			.{}
		);
		return 1;
	}

	// The decategorizing in question
	transaction.delete(&catman) catch return 1;
	return 0;
}

pub fn dry_install(allocator: Allocator, config: *Config, args: []const [:0]u8) u8 {
	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var transaction =
		Transaction.init(allocator, args, &catman, config, null) catch return 1;
	defer transaction.deinit(allocator);

	// The categorizing in question
	transaction.write(&catman, config) catch return 1;
	return 0;
}

pub fn dry_uninstall(allocator: Allocator, config: *Config, args: []const [:0]u8) u8 {
	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var transaction =
		Transaction.init(allocator, args, &catman, config, null) catch return 1;
	defer transaction.deinit(allocator);

	// The decategorizing in question
	transaction.delete(&catman) catch return 1;
	return 0;
}

pub fn list(allocator: Allocator, config: *Config, args: []const [:0]u8) u8 {
	if (args.len > 3) {
		meta.errln("Invalid args!\nSee 'pakt help' for correct usage!", .{});
		return 1;
	}
	const separator: []const u8 = if (args.len < 3) "  " else args[2];

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var cat_list = StringListOwned.init_capacity(allocator, 8) catch return 1;
	defer cat_list.deinit(allocator);
	catman.append_all_cat_names(allocator, &cat_list) catch return 1;

	const string = std.mem.join(allocator, separator, cat_list.data.items) catch return 1;
	defer allocator.free(string);

	meta.print("{s}\n", .{string});
	return 0;
}

pub fn find(config: *Config, args: []const [:0]u8) u8 {
	if (args.len < 3) {
		meta.errln("Missing package names!\nSee 'pakt help' for correct usage!", .{});
		return 1;
	}

	var stat: u8 = 1;

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var buf: [1024]u8 = undefined;
	var it = catman.dir.iterate();

	cat: while (it.next() catch return 1) |entry| {
		var catfile = catman.open_catfile(entry.name) catch return 1;
		defer catfile.close();

		var reader = catfile.reader(&buf);
		while (reader.interface.takeDelimiterExclusive('\n') catch null) |line| {
			const uncommented = std.mem.trim(u8, blk: {
				const hash_i =
					std.mem.indexOfScalar(u8, line, '#') orelse break :blk line;
				break :blk line[0..hash_i];
			}, " ");
			for (args[2..]) |pkg| if (meta.eql(uncommented, pkg)) {
				stat = 0;
				meta.print("{s}\n", .{entry.name});
				continue :cat;
			};
		}
	}

	return stat;
}

pub fn edit(allocator: Allocator, config: *Config, args: []const [:0]u8) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 3) catch return 1;
	defer cmd.deinit(allocator);

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var file_list = StringListOwned.init_capacity(allocator, 2) catch return 1;
	defer file_list.deinit(allocator);
	catman.write_file_list(allocator, args[2..], config, &file_list) catch return 1;

	cmd.append(allocator, config.editor) catch return 1;
	cmd.appendSlice(allocator, file_list.data.items) catch return 1;

	var child = std.process.Child.init(cmd.items, allocator);
	const term = child.spawnAndWait() catch return 1;
	return term.Exited;
}

pub fn purge(config: *const Config, args: []const [:0]u8) u8 {
	var stdin_buf: [128]u8 = undefined;
	var stdin = std.fs.File.stdin().reader(&stdin_buf);

	for (args[2..]) |arg| meta.print(" +{s}", .{arg});
	meta.print(
		"\nAre you sure you want to delete these categories? Type 'yes' to proceed: ",
		.{}
	);
	meta.outflush();

	const response = stdin.interface.takeDelimiterExclusive('\n') catch return 1;
	if (!meta.eql(response, "yes")) return 1;

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var stat: u8 = 0;
	for (args[2..]) |cat| catman.dir.deleteFile(cat) catch {
		meta.errln("Failed to delete +{s}", .{cat});
		stat |= 1;
	};
	return stat;
}

pub fn native(allocator: Allocator, config: *const Config, args: []const [:0]u8) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 3) catch return 1;
	defer cmd.deinit(allocator);

	cmd.append(allocator, config.package_manager) catch return 1;
	cmd.appendSlice(allocator, args[2..]) catch return 1;

	var child = std.process.Child.init(cmd.items, allocator);
	const term = child.spawnAndWait() catch return 1;
	return term.Exited;
}

pub fn help(config_path: []const u8) void {
	std.debug.print(
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
