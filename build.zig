const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "catlang",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run unit tests");
    // Tokenizer tests
    const tokenizer_tests = b.addTest(.{
        .root_source_file = b.path("src/test_tokenizer.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tokenizer_tests = b.addRunArtifact(tokenizer_tests);
    test_step.dependOn(&run_tokenizer_tests.step);

    // Parser tests
    const parser_tests = b.addTest(.{
        .root_source_file = b.path("src/test_parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_parser_tests = b.addRunArtifact(parser_tests);
    test_step.dependOn(&run_parser_tests.step);

    // ZLS
    const exe_check = b.addExecutable(.{
        .name = "catlang",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);
}
