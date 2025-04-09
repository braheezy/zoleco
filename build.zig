const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var modules = std.StringHashMap(*std.Build.Module).init(std.heap.page_allocator);
    defer modules.deinit();

    // Add sysaudio to play raw audio on the host
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // Define our local modules
    const sn76489_mod = b.addModule("SN76489", .{ .root_source_file = b.path("src/SN76489.zig") });
    const z80_mod = b.addModule("z80", .{ .root_source_file = b.path("src/root.zig") });
    const tms9918_mod = b.addModule("tms9918", .{ .root_source_file = b.path("src/TMS9918.zig") });

    try modules.put("SN76489", sn76489_mod);
    try modules.put("z80", z80_mod);
    try modules.put("tms9918", tms9918_mod);
    try modules.put("raylib", raylib);
    try modules.put("raygui", raygui);

    // Create main executable
    const exe = b.addExecutable(.{
        .name = "colecovision",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(raylib_artifact);
    b.installArtifact(exe);

    // Create non-install compile step for code editors to check
    const exe_check = b.addExecutable(.{
        .name = "check",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_check.linkLibrary(raylib_artifact);

    addModulesToExe(exe_check, modules, &[_][]const u8{ "SN76489", "z80", "tms9918", "raylib", "raygui" });
    addModulesToExe(exe, modules, &[_][]const u8{ "SN76489", "z80", "tms9918", "raylib", "raygui" });

    const check = b.step("check", "Check if it compiles");
    check.dependOn(&exe_check.step);

    defineRun(b, exe);
    try defineCpuTest(b, target, optimize, modules);
    defineExamples(b, target, optimize, modules, raylib_artifact);
}

fn defineRun(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn defineCpuTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: std.StringHashMap(*std.Build.Module),
) !void {
    _ = optimize;
    const cpu_test = b.addExecutable(.{
        .name = "cputest",
        .root_source_file = b.path("examples/z80_tester/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    addModulesToExe(cpu_test, modules, &[_][]const u8{"z80"});

    const test_step = b.step("cputest", "Run cpu tests");
    const run_test = b.addRunArtifact(cpu_test);
    b.installArtifact(cpu_test);

    // Set the working directory to the z80_tester directory
    run_test.cwd = .{ .cwd_relative = b.pathFromRoot("examples/z80_tester") };

    if (b.args) |args| {
        run_test.addArgs(args);
    }

    test_step.dependOn(&run_test.step);
}

// Helper function for adding modules selectively
fn addModulesToExe(
    exe: *std.Build.Step.Compile,
    modules: std.StringHashMap(*std.Build.Module),
    targets: []const []const u8,
) void {
    for (targets) |name| {
        exe.root_module.addImport(name, modules.get(name) orelse unreachable);
    }
}

fn defineExamples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: std.StringHashMap(*std.Build.Module),
    raylib_artifact: *std.Build.Step.Compile,
) void {
    const vgm_player_exe = b.addExecutable(.{
        .name = "vgm_player",
        .root_source_file = b.path("examples/vgm_player/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    addModulesToExe(vgm_player_exe, modules, &[_][]const u8{ "SN76489", "raylib" });
    vgm_player_exe.linkLibrary(raylib_artifact);
    b.installArtifact(vgm_player_exe);

    const tms9918_viewer_exe = b.addExecutable(.{
        .name = "tms9918_viewer",
        .root_source_file = b.path("examples/tms9918_viewer/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    tms9918_viewer_exe.linkLibrary(raylib_artifact);
    addModulesToExe(tms9918_viewer_exe, modules, &[_][]const u8{ "tms9918", "raylib" });
    b.installArtifact(tms9918_viewer_exe);

    const run_cmd = b.addRunArtifact(tms9918_viewer_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("example", "build an example");
    run_step.dependOn(&run_cmd.step);
}
