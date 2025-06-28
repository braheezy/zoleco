const std = @import("std");
const sdl = @import("sdl");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const sdk = sdl.init(b, .{});
    const sdl_mod = sdk.getNativeModule();

    // Define our local modules
    const sn76489_mod = b.addModule("SN76489", .{ .root_source_file = b.path("src/SN76489.zig") });
    const z80_mod = b.addModule("z80", .{ .root_source_file = b.path("src/root.zig") });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create main executable
    const exe = b.addExecutable(.{
        .name = "zoleco",
        .root_module = exe_mod,
    });
    sdk.link(exe, .static, sdl.Library.SDL2);

    b.installArtifact(exe);

    exe_mod.addImport("SN76489", sn76489_mod);
    exe_mod.addImport("z80", z80_mod);
    exe_mod.addImport("sdl2", sdl_mod);

    defineRun(b, exe);

    const cpu_test_mod = b.createModule(.{
        .root_source_file = b.path("examples/z80_tester/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    cpu_test_mod.addImport("z80", z80_mod);

    const cpu_test = b.addExecutable(.{
        .name = "cputest",
        .root_module = cpu_test_mod,
    });

    const test_step = b.step("cputest", "Run cpu tests");
    const run_test = b.addRunArtifact(cpu_test);
    b.installArtifact(cpu_test);

    // Set the working directory to the z80_tester directory, so tests is relative
    run_test.cwd = .{ .cwd_relative = b.pathFromRoot("examples/z80_tester") };
    if (b.args) |args| {
        run_test.addArgs(args);
    }
    test_step.dependOn(&run_test.step);

    const vgm_player_exe = defineVgmPlayer(
        b,
        target,
        optimize,
        sn76489_mod,
        sdk.getWrapperModule(),
    );
    sdk.link(vgm_player_exe, .static, sdl.Library.SDL2);
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

fn defineVgmPlayer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    sn76489_mod: *std.Build.Module,
    sdl_mod: *std.Build.Module,
) *std.Build.Step.Compile {
    const vgm_player_mod = b.createModule(.{
        .root_source_file = b.path("examples/vgm_player/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    vgm_player_mod.addImport("SN76489", sn76489_mod);
    vgm_player_mod.addImport("sdl2", sdl_mod);

    const vgm_player_exe = b.addExecutable(.{
        .name = "vgm_player",
        .root_module = vgm_player_mod,
    });

    b.installArtifact(vgm_player_exe);

    const run_cmd = b.addRunArtifact(vgm_player_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("vgm", "Run the vgm example");
    run_step.dependOn(&run_cmd.step);

    return vgm_player_exe;
}
