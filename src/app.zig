const std = @import("std");
const SDL = @import("sdl2");
const Emu = @import("emu.zig").Emu;
const Renderer = @import("renderer.zig");

// Import resolution constants from video.zig
const resolution_width_with_overscan = @import("video.zig").resolution_width_with_overscan;
const resolution_height_with_overscan = @import("video.zig").resolution_height_with_overscan;

pub const window_width = 640;
pub const window_height = 480;

pub const App = struct {
    window: *SDL.SDL_Window = undefined,
    display_scale: f32 = 1.0,
    emu: *Emu = undefined,
    renderer: *Renderer = undefined,
    running: bool = true,
    frame_time_start: u64 = 0,
    frame_time_end: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, rom_file: []const u8) !App {
        var app = App{};

        app.sdlInit();
        app.emu = try Emu.init(allocator);
        app.renderer = try Renderer.init(allocator, app.emu.framebuffer);

        // Initialize SDL components of the renderer after window creation
        try app.renderer.initSDL(app.window);

        try app.emu.loadRom(allocator, rom_file);
        return app;
    }

    fn sdlInit(self: *App) void {
        if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_TIMER) < 0)
            sdlPanic();

        const window_flags = SDL.SDL_WINDOW_ALLOW_HIGHDPI;

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
        SDL.SDL_GetWindowSize(self.window, &display_w, &display_h);

        if (w > 0 and h > 0) {
            const scale_w = (@as(f32, @floatFromInt(display_w)) / @as(f32, @floatFromInt(w)));
            const scale_h = (@as(f32, @floatFromInt(display_h)) / @as(f32, @floatFromInt(h)));

            self.display_scale = if (scale_w > scale_h) scale_w else scale_h;
        }

        _ = SDL.SDL_EventState(SDL.SDL_DROPFILE, SDL.SDL_ENABLE);
    }

    pub fn deinit(self: *App, allocator: std.mem.Allocator) void {
        // std.log.info("Deiniting App", .{});
        self.emu.deinit(allocator);
        self.renderer.deinit(allocator);
        _ = SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    pub fn loop(self: *App) !void {
        while (self.running) {
            self.frame_time_start = SDL.SDL_GetPerformanceCounter();

            self.handleSdlEvents();
            // TODO: handle_mouse_cursor()
            try self.run_emu();
            self.render();
            self.frame_time_end = SDL.SDL_GetPerformanceCounter();
            self.frameThrottle();
        }
    }

    fn frameThrottle(self: *App) void {
        const elapsed: f32 = @floatFromInt(((self.frame_time_end - self.frame_time_start) * 1000) / SDL.SDL_GetPerformanceFrequency());

        const min: f32 = 16.666;

        if (elapsed < min) {
            SDL.SDL_Delay(@intFromFloat(min - elapsed));
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
        self.renderer.render();
    }
};

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
