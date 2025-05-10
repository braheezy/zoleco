const std = @import("std");
const SDL = @import("sdl2");
const Emu = @import("emu.zig").Emu;

const window_width = 640;
const window_height = 480;

pub const App = struct {
    window: *SDL.SDL_Window = undefined,
    renderer: *SDL.SDL_Renderer = undefined,
    texture: *SDL.SDL_Texture = undefined,
    display_scale: f32 = 1.0,
    emu: *Emu = undefined,
    running: bool = true,
    frame_time_start: u64 = 0,
    frame_time_end: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, rom_file: []const u8) !App {
        var app = App{};

        app.sdlInit();
        app.emu = try Emu.init(allocator);
        app.initRenderer();

        try app.emu.loadRom(allocator, rom_file);
        return app;
    }

    fn sdlInit(self: *App) void {
        if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_TIMER) < 0)
            sdlPanic();
        _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_DOUBLEBUFFER, 1);
        _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_DEPTH_SIZE, 24);
        _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_STENCIL_SIZE, 8);
        _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
        _ = SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MINOR_VERSION, 2);
        const window_flags = (SDL.SDL_WINDOW_OPENGL | SDL.SDL_WINDOW_ALLOW_HIGHDPI);

        self.window = SDL.SDL_CreateWindow(
            "Zoleco",
            SDL.SDL_WINDOWPOS_CENTERED,
            SDL.SDL_WINDOWPOS_CENTERED,
            window_width,
            window_height,
            window_flags,
        ) orelse sdlPanic();
        _ = SDL.SDL_SetWindowMinimumSize(self.window, 500, 300);

        var w: i32 = undefined;
        var h: i32 = undefined;
        SDL.SDL_GetWindowSize(self.window, &w, &h);
        var display_w: i32 = undefined;
        var display_h: i32 = undefined;
        SDL.SDL_GL_GetDrawableSize(self.window, &display_w, &display_h);

        if (w > 0 and h > 0) {
            const scale_w = (@as(f32, @floatFromInt(display_w)) / @as(f32, @floatFromInt(w)));
            const scale_h = (@as(f32, @floatFromInt(display_h)) / @as(f32, @floatFromInt(h)));

            self.display_scale = if (scale_w > scale_h) scale_w else scale_h;
        }

        _ = SDL.SDL_EventState(SDL.SDL_DROPFILE, SDL.SDL_ENABLE);
    }

    pub fn deinit(self: *App, allocator: std.mem.Allocator) void {
        std.log.info("Deiniting App", .{});
        self.emu.deinit(allocator);
        _ = SDL.SDL_DestroyRenderer(self.renderer);
        _ = SDL.SDL_DestroyTexture(self.texture);
        _ = SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    fn initRenderer(self: *App) void {
        const render_flags = SDL.SDL_RENDERER_ACCELERATED | SDL.SDL_RENDERER_PRESENTVSYNC;
        self.renderer = SDL.SDL_CreateRenderer(self.window, -1, render_flags) orelse sdlPanic();
        _ = SDL.SDL_SetHint(SDL.SDL_HINT_RENDER_SCALE_QUALITY, "0");
        _ = SDL.SDL_RenderSetLogicalSize(self.renderer, window_width, window_height);
        self.texture = SDL.SDL_CreateTexture(self.renderer, SDL.SDL_PIXELFORMAT_RGB24, SDL.SDL_TEXTUREACCESS_STREAMING, window_width, window_height) orelse sdlPanic();
    }

    pub fn loop(self: *App) !void {
        while (self.running) {
            self.frame_time_start = SDL.SDL_GetPerformanceCounter();

            self.handleSdlEvents();
            // TODO: handle_mouse_cursor()
            try self.run_emu();
            self.render();
            self.frame_time_end = SDL.SDL_GetPerformanceCounter();
            // self.frameThrottle();
        }
    }

    fn handleSdlEvents(self: *App) void {
        var event: SDL.SDL_Event = undefined;

        while (SDL.SDL_PollEvent(&event) != 0) {
            if (event.type == SDL.SDL_QUIT) {
                self.running = false;
                break;
            }

            if (event.type == SDL.SDL_WINDOWEVENT and event.window.event == SDL.SDL_WINDOWEVENT_CLOSE and event.window.windowID == SDL.SDL_GetWindowID(self.window)) {
                self.running = false;
                break;
            }

            switch (event.type) {
                SDL.SDL_KEYDOWN => {
                    const key = event.key.keysym.scancode;

                    if (key == SDL.SDL_SCANCODE_ESCAPE) {
                        var e: SDL.SDL_Event = undefined;
                        e.type = SDL.SDL_QUIT;
                        _ = SDL.SDL_PushEvent(&e);
                    }
                },
                else => {},
            }
        }
    }

    fn run_emu(self: *App) !void {
        SDL.SDL_SetWindowTitle(self.window, "zoleco");
        try self.emu.update();
    }

    fn render(self: *App) void {
        // Clear the screen with a dark color
        _ = SDL.SDL_SetRenderDrawColor(self.renderer, 25, 25, 25, 255);
        _ = SDL.SDL_RenderClear(self.renderer);

        // Update the texture with the framebuffer data
        var pixels: ?*anyopaque = undefined;
        var pitch: c_int = undefined;

        if (SDL.SDL_LockTexture(self.texture, null, &pixels, &pitch) < 0) {
            sdlPanic();
        }

        // Copy the framebuffer data to the texture
        @memcpy(@as([*]u8, @ptrCast(pixels))[0..self.emu.framebuffer.len], self.emu.framebuffer);

        SDL.SDL_UnlockTexture(self.texture);

        // Render the texture to the screen
        _ = SDL.SDL_RenderCopy(self.renderer, self.texture, null, null);

        // Present the renderer
        SDL.SDL_RenderPresent(self.renderer);
    }
};

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
