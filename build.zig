const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_exe = b.addExecutable(.{
        .name = "gobz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "deps/include" } });
    main_exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "deps/src/stb_image_impl.c" } } });
    main_exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "deps/src/stb_image_write_impl.c" } } });
    main_exe.linkSystemLibrary("SDL2");
    main_exe.linkLibC();
    b.installArtifact(main_exe);
}
