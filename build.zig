const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var modules = std.StringHashMap(*std.Build.Module).init(std.heap.page_allocator);
    defer modules.deinit();

    // Add sysaudio to play raw audio on the host
    const mach_mod = b.dependency("mach", .{
        .target = target,
        .optimize = optimize,
        .sysaudio = true,
    }).module("mach");

    // Define our local modules
    const sn76489_mod = b.addModule("SN76489", .{ .root_source_file = b.path("src/SN76489.zig") });
    const z80_mod = b.addModule("z80", .{ .root_source_file = b.path("src/cpu/Z80.zig") });

    try modules.put("mach", mach_mod);
    try modules.put("SN76489", sn76489_mod);
    try modules.put("z80", z80_mod);

    // Create main executable
    const exe = b.addExecutable(.{
        .name = "colecovision",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // Create non-install compile step for code editors to check
    const exe_check = b.addExecutable(.{
        .name = "check",
        .root_source_file = b.path("examples/z80_disassembler/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    addModulesToExe(exe_check, modules, &[_][]const u8{ "mach", "SN76489", "z80" });
    addModulesToExe(exe, modules, &[_][]const u8{ "mach", "SN76489", "z80" });

    const check = b.step("check", "Check if it compiles");
    check.dependOn(&exe_check.step);

    defineRun(b, exe);
    defineTests(b, target, optimize);
    defineExamples(b, target, optimize, modules);
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

fn defineTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
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
) void {
    const vgm_player_exe = b.addExecutable(.{
        .name = "vgm_player",
        .root_source_file = b.path("examples/vgm_player/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    addModulesToExe(vgm_player_exe, modules, &[_][]const u8{ "mach", "SN76489" });
    b.installArtifact(vgm_player_exe);

    const z80_disassembler_exe = b.addExecutable(.{
        .name = "z80_disassembler",
        .root_source_file = b.path("examples/z80_disassembler/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    addModulesToExe(z80_disassembler_exe, modules, &[_][]const u8{"z80"});
    b.installArtifact(z80_disassembler_exe);
}
