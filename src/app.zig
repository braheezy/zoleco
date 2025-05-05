const std = @import("std");
const SDL = @import("sdl2");
const Emu = @import("emu.zig").Emu;

const window_width = 640;
const window_height = 480;

pub const App = struct {
    window: *SDL.SDL_Window = undefined,
    gl_context: *SDL.SDL_GLContext = undefined,
    display_scale: f32 = 1.0,

    pub fn init(allocator: std.mem.Allocator, rom_file: []const u8) !void {
        _ = rom_file;

        var app = App{};

        app.sdlInit();
        _ = try Emu.init(allocator);

        const renderer = SDL.SDL_CreateRenderer(app.window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
        defer _ = SDL.SDL_DestroyRenderer(renderer);

        mainLoop: while (true) {
            var ev: SDL.SDL_Event = undefined;
            while (SDL.SDL_PollEvent(&ev) != 0) {
                if (ev.type == SDL.SDL_KEYDOWN and ev.key.keysym.sym == SDL.SDLK_ESCAPE)
                    break :mainLoop;
            }

            _ = SDL.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF);
            _ = SDL.SDL_RenderClear(renderer);

            SDL.SDL_RenderPresent(renderer);
        }
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
        const gl_context = SDL.SDL_GL_CreateContext(self.window) orelse sdlPanic();
        defer _ = SDL.SDL_GL_DeleteContext(gl_context);
        _ = SDL.SDL_GL_MakeCurrent(self.window, gl_context);
        _ = SDL.SDL_GL_SetSwapInterval(0);
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

    pub fn deinit(self: *App) void {
        _ = SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }
};

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
