const std = @import("std");
const SDL = @import("sdl2");
const video = @import("video.zig");

const window_width = @import("app.zig").window_width;
const window_height = @import("app.zig").window_height;

pub const Renderer = @This();

// SDL-specific fields
sdl_renderer: *SDL.SDL_Renderer,
texture: *SDL.SDL_Texture,
framebuffer: []u8,

pub fn init(allocator: std.mem.Allocator, framebuffer: []u8) !*Renderer {
    const self = try allocator.create(Renderer);
    self.* = Renderer{
        .sdl_renderer = undefined, // Will be set by app.zig
        .texture = undefined, // Will be set by app.zig
        .framebuffer = framebuffer,
    };

    return self;
}

pub fn initSDL(self: *Renderer, window: *SDL.SDL_Window) !void {
    const render_flags = SDL.SDL_RENDERER_ACCELERATED | SDL.SDL_RENDERER_PRESENTVSYNC;

    self.sdl_renderer = SDL.SDL_CreateRenderer(window, -1, render_flags) orelse {
        const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
        @panic(std.mem.sliceTo(str, 0));
    };

    _ = SDL.SDL_SetHint(SDL.SDL_HINT_RENDER_SCALE_QUALITY, "0");
    _ = SDL.SDL_RenderSetLogicalSize(self.sdl_renderer, window_width, window_height);

    // Try creating texture with the standard 256x192 resolution instead of overscan
    // to see if overscan is causing stride issues
    self.texture = SDL.SDL_CreateTexture(self.sdl_renderer, SDL.SDL_PIXELFORMAT_BGR24, SDL.SDL_TEXTUREACCESS_STREAMING, video.resolution_width, video.resolution_height) orelse {
        const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
        @panic(std.mem.sliceTo(str, 0));
    };
}

pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
    _ = SDL.SDL_DestroyTexture(self.texture);
    _ = SDL.SDL_DestroyRenderer(self.sdl_renderer);
    allocator.destroy(self);
}

pub fn render(self: *Renderer) void {
    // Clear the renderer
    _ = SDL.SDL_SetRenderDrawColor(self.sdl_renderer, 0, 0, 0, 255);
    _ = SDL.SDL_RenderClear(self.sdl_renderer);

    // Debug: print first few bytes of framebuffer
    // std.debug.print("Framebuffer first 12 bytes: ", .{});
    // for (self.framebuffer[0..12]) |byte| {
    //     std.debug.print("{X:02} ", .{byte});
    // }
    // std.debug.print("\n", .{});

    // Try different approaches to fix the smearing issue

    // Approach 1: Try with BGR format instead of RGB
    // The issue might be that SDL expects BGR but we're providing RGB

    // Update texture with framebuffer data - try with proper stride
    const stride = @as(c_int, @intCast(video.resolution_width * 3));
    _ = SDL.SDL_UpdateTexture(self.texture, null, // Update entire texture
        self.framebuffer.ptr, stride);

    // Calculate scaling to fit the window while maintaining aspect ratio
    const src_rect = SDL.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = @as(c_int, @intCast(video.resolution_width)),
        .h = @as(c_int, @intCast(video.resolution_height)),
    };

    // Render the texture scaled to fit the window
    _ = SDL.SDL_RenderCopy(self.sdl_renderer, self.texture, &src_rect, null);

    // Present the frame
    SDL.SDL_RenderPresent(self.sdl_renderer);
}
