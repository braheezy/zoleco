const std = @import("std");
const SDL = @import("sdl2");
const video = @import("video.zig");
const gl = @import("opengl.zig");

const FRAME_BUFFER_SCALE: u32 = 4;
const FRAME_BUFFER_WIDTH: u32 = video.resolution_width_with_overscan * FRAME_BUFFER_SCALE;
const FRAME_BUFFER_HEIGHT: u32 = video.resolution_height_with_overscan * FRAME_BUFFER_SCALE;
const window_width = @import("app.zig").window_width;
const window_height = @import("app.zig").window_height;

pub const Renderer = @This();

systemTexture: u32 = 0,
scanlinesTexture: u32 = 0,
frameBufferObject: u32 = 0,
rendererEmuTexture: u32 = 0,
rendererEmuDebugVramBackground: u32 = 0,
rendererEmuDebugVramTiles: u32 = 0,
rendererEmuDebugVramSprites: [64]u32 = undefined,
firstFrame: bool = false,
framebuffer: []u8 = undefined,
pub fn init(allocator: std.mem.Allocator, framebuffer: []u8) !*Renderer {
    const version = gl.getString(gl.VERSION);
    std.debug.print("Using OpenGL {s}\n", .{version});

    const self = try allocator.create(Renderer);
    self.* = Renderer{ .framebuffer = framebuffer };

    self.initEmu();
    self.firstFrame = true;
    return self;
}

pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
    gl.deleteFramebuffers(1, &self.frameBufferObject);
    gl.deleteTextures(1, &self.rendererEmuTexture);
    gl.deleteTextures(1, &self.systemTexture);
    gl.deleteTextures(1, &self.rendererEmuDebugVramBackground);
    gl.deleteTextures(1, &self.rendererEmuDebugVramTiles);
    gl.deleteTextures(64, &self.rendererEmuDebugVramSprites[0]);
    allocator.destroy(self);
}

fn initEmu(self: *Renderer) void {
    gl.enable(gl.TEXTURE_2D);

    gl.genFramebuffers(1, &self.frameBufferObject);
    gl.genTextures(1, &self.rendererEmuTexture);
    gl.genTextures(1, &self.systemTexture);

    gl.bindFramebuffer(gl.FRAMEBUFFER, self.frameBufferObject);
    gl.bindTexture(gl.TEXTURE_2D, self.rendererEmuTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, FRAME_BUFFER_WIDTH, FRAME_BUFFER_HEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.rendererEmuTexture, 0);
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    gl.bindTexture(gl.TEXTURE_2D, self.systemTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, video.resolution_width_with_overscan, video.resolution_height_with_overscan, 0, gl.RGB, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
}

pub fn render(self: *Renderer) void {
    // Debug check for OpenGL errors at start of frame
    self.checkOpenGLError("start of frame");

    // Clear the main window
    gl.viewport(0, 0, window_width, window_height);
    gl.clearColor(0.1, 0.1, 0.1, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    // Test both rendering paths
    self.renderEmuNormal();

    // Update emu texture parameters
    self.updateEmuTexture();

    // Check framebuffer status
    self.checkFramebufferStatus();

    // Directly draw the systemTexture to the screen
    gl.bindTexture(gl.TEXTURE_2D, self.rendererEmuTexture);
    renderQuad();

    // Debug check for OpenGL errors at end of frame
    self.checkOpenGLError("end of frame");
}

fn renderEmuNormal(self: *Renderer) void {
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.frameBufferObject);
    gl.disable(gl.BLEND);
    self.updateSystemTexture();
    renderQuad();
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
}

fn updateSystemTexture(self: *Renderer) void {
    gl.bindTexture(gl.TEXTURE_2D, self.systemTexture);
    gl.texSubImage2D(
        gl.TEXTURE_2D,
        0,
        0,
        0,
        video.resolution_width_with_overscan,
        video.resolution_height_with_overscan,
        gl.RGB,
        gl.UNSIGNED_BYTE,
        @ptrCast(self.framebuffer.ptr),
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    useNearestFilters();
}

fn updateEmuTexture(self: *Renderer) void {
    gl.bindTexture(gl.TEXTURE_2D, self.rendererEmuTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    // In C++ this would check for scanlines config
    // In our case we'll just use nearest neighbor
    useNearestFilters();
}

fn renderQuad() void {
    gl.matrixMode(gl.PROJECTION);
    gl.loadIdentity();
    gl.ortho(0, 1.0, 0, 1.0, -1, 1);
    gl.matrixMode(gl.MODELVIEW);
    gl.viewport(0, 0, FRAME_BUFFER_WIDTH, FRAME_BUFFER_HEIGHT);
    gl.begin(gl.QUADS);
    gl.texCoord2d(0, 0);
    gl.vertex2d(0, 0);
    gl.texCoord2d(1, 0);
    gl.vertex2d(1, 0);
    gl.texCoord2d(1, 1);
    gl.vertex2d(1, 1);
    gl.texCoord2d(0, 1);
    gl.vertex2d(0, 1);
    gl.end();
}

var round_error = false;
fn renderEmuMix(self: *Renderer) void {
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.frameBufferObject);
    var alpha: f32 = 0.15 + (0.50 * (1.0 - 0.6));
    if (self.firstFrame) {
        self.firstFrame = false;
        alpha = 1.0;
        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);
    }

    const delta: f32 = if (round_error) 0.03 else 0.0;
    const round_color: f32 = 1.0 - delta;
    round_error = !round_error;

    gl.enable(gl.BLEND);
    gl.color4f(round_color, round_color, round_color, alpha);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    self.updateSystemTexture();

    renderQuad();

    gl.color4f(1.0, 1.0, 1.0, 1.0);
    gl.disable(gl.BLEND);

    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
}

fn useLinearFilters() void {
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
}

fn useNearestFilters() void {
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
}

fn checkFramebufferStatus(self: *Renderer) void {
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.frameBufferObject);
    const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
    if (status != gl.FRAMEBUFFER_COMPLETE) {
        std.debug.print("ERROR: Framebuffer is not complete! Status: {}\n", .{status});
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
}

fn checkOpenGLError(self: *Renderer, location: []const u8) void {
    _ = self;
    const err = gl.getError();
    if (err != gl.NO_ERROR) {
        std.debug.print("OpenGL error at {s}: {}\n", .{ location, err });
    }
}
