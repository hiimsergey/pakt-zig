const std = @import("std");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const ArrayList = std.ArrayList;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const Transaction = @import("Transaction.zig");

pub fn install(allocator: Allocator, config: *Config, args: *ArgIterator) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 4) catch return 1;
	defer cmd.deinit(allocator);
	cmd.appendSlice(allocator, &.{config.package_manager, config.install_arg}) catch
		return 1;

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var transaction = Transaction.init(allocator, args, &catman, config, &cmd) catch
		return 1;
	defer transaction.deinit(allocator);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = child.spawnAndWait() catch return 1;
	if (term.Exited != 0) {
		meta.fail(
			"Package manager operation didn't succeed, thus no categorizing happens.",
			.{}
		);
		return 1;
	}

	// The categorizing in question
	transaction.write(&catman, config) catch return 1;
	return 0;
}

pub fn uninstall(allocator: Allocator, config: *Config, args: *ArgIterator) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 4) catch return 1;
	defer cmd.deinit(allocator);
	cmd.appendSlice(allocator, &.{config.package_manager, config.uninstall_arg}) catch
		return 1;

	var catman = Categories.init(config) catch return 1;
	defer catman.deinit();

	var transaction = Transaction.init(allocator, args, &catman, config, &cmd) catch
		return 1;
	defer transaction.deinit(allocator);

	var child = std.process.Child.init(cmd.items, allocator);
	const term = child.spawnAndWait() catch return 1;
	if (term.Exited != 0) {
		meta.fail(
			"Package manager operation didn't succeed, thus no decategorizing happens.",
			.{}
		);
		return 1;
	}

	// The decategorizing in question
	transaction.delete(&catman) catch return 1;
	return 0;
}

pub fn native(allocator: Allocator, config: *const Config, args: *ArgIterator) u8 {
	var cmd = ArrayList([]const u8).initCapacity(allocator, 3) catch return 1;
	defer cmd.deinit(allocator);

	cmd.append(allocator, config.package_manager) catch return 1;
	while (args.next()) |arg| cmd.append(allocator, arg) catch return 1;

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
\\    pakt l(ist)             ls-arg...             list all user-defined categories
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
