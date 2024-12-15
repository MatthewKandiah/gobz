const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_exe = b.addExecutable(.{
        .name = "gobz",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_exe.linkLibC();
    main_exe.linkSystemLibrary("SDL2");
    b.installArtifact(main_exe);
}
