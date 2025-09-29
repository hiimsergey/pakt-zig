// TODO FINAL TEST
// json valid but incomplete

const std = @import("std");
const Transaction = @import("Transaction.zig");
const meta = @import("meta.zig");

const Allocator = std.mem.Allocator;
const AllocatorWrapper = @import("allocator.zig").AllocatorWrapper;
const ArrayList = std.ArrayList;
const ArgIterator = std.process.ArgIterator;
const Categories = @import("Categories.zig");
const Config = @import("Config.zig");
const Parsed = std.json.Parsed;

fn install(allocator: Allocator, config: *Config, args: *ArgIterator) u8 {
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

fn uninstall(allocator: Allocator, config: *Config, args: *ArgIterator) u8 {
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

fn help(config_path: []const u8) void {
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

pub fn main() u8 {
	var aw = AllocatorWrapper.init();
	defer aw.deinit();
	const allocator = aw.allocator();

	defer meta.flush();

	const config_path = Config.get_config_path(allocator) catch return 1;
	defer allocator.free(config_path);

	var config: Parsed(Config) = Config.parse(allocator, config_path) catch return 1;
	defer config.deinit();

	var args = std.process.args();
	_ = args.skip(); // skip "pakt"

	const subcommand = args.next() orelse {
		config.value.call_no_arg_action(allocator) catch return 1;
		return 0;
	};

	const eql = meta.eql;
	return if (eql(subcommand, "install") or eql(subcommand, "i"))
		install(allocator, &config.value, &args)
	else if (eql(subcommand, "uninstall") or eql(subcommand, "u"))
		uninstall(allocator, &config.value, &args)
	else if (eql(subcommand, "help") or eql(subcommand, "h")) {
		help(config_path);
		return 0;
	} else {
		meta.fail(
			"Invalid subcommand {s}!\nSee 'pakt help' for available options!",
			.{subcommand}
		);
		return 1;
	};
}
