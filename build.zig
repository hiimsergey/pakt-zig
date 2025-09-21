const Build = @import("std").Build;

// Latest Zig version as of writing this: 0.15.1
pub fn build(b: *Build) void {
	// Options
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	// Executable declaration
	const exe = b.addExecutable(.{
		.name = "pakt",
		.root_source_file = b.path("pakt.zig"),
		.target = target,
		.optimize = optimize
	});

	exe.linkLibC(); // Needed for `std.heap.c_allocator`

	// Actual installation
	b.installArtifact(exe);

	// Run command
	const run_exe = b.addRunArtifact(exe);
	const run_step = b.step("run", "Run the program");
	run_step.dependOn(&run_exe.step);

}
