const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libarp_mod = b.addModule("libarp", .{
        .root_source_file = b.path("src/libarp.zig"),
        .target = target,
    });
    _ = libarp_mod;

    const lib = b.addLibrary(.{
        .name = "arp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/libarp.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    const want_shared = b.option(bool, "shared", "Also build a shared library (.dll/.so/.dylib)") orelse false;
    if (want_shared) {
        const shared = b.addLibrary(.{
            .name = "arp",
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/libarp.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        b.installArtifact(shared);
    }

    const lib_tests = b.addTest(.{ .root_module = lib.root_module });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run libarp tests");
    test_step.dependOn(&run_lib_tests.step);
}
