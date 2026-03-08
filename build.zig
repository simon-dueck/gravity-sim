const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    //const mod = b.addModule("gravity_sdl", .{
    //    .root_source_file = b.path("src/root.zig"),
    //    .target = target,
    //});


    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "gravity_sdl3",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    exe.linkLibC();
    exe.linkLibrary(sdl_dep.artifact("SDL3"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| { run_cmd.addArgs(args); }

    // tests
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });

    exe_tests.linkLibC();
    exe_tests.linkLibrary(sdl_dep.artifact("SDL3"));

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);

}
