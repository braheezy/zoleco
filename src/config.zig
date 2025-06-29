const builtin = @import("builtin");
const SDL = @import("sdl2");
const SDL_Scancode = SDL.SDL_Scancode;

pub const Input = struct {
    left: SDL_Scancode,
    right: SDL_Scancode,
    up: SDL_Scancode,
    down: SDL_Scancode,
    left_button: SDL_Scancode,
    right_button: SDL_Scancode,
    blue: SDL_Scancode,
    purple: SDL_Scancode,
    zero: SDL_Scancode,
    one: SDL_Scancode,
    two: SDL_Scancode,
    three: SDL_Scancode,
    four: SDL_Scancode,
    five: SDL_Scancode,
    six: SDL_Scancode,
    seven: SDL_Scancode,
    eight: SDL_Scancode,
    nine: SDL_Scancode,
    asterisk: SDL_Scancode,
    hash: SDL_Scancode,
    gamepad: bool,
    gamepad_directional: u8,
    gamepad_invert_x_axis: bool,
    gamepad_invert_y_axis: bool,
    gamepad_left_button: u8,
    gamepad_right_button: u8,
    gamepad_blue: u8,
    gamepad_purple: u8,
    gamepad_x_axis: u8,
    gamepad_y_axis: u8,
    gamepad_1: u8,
    gamepad_2: u8,
    gamepad_3: u8,
    gamepad_4: u8,
    gamepad_5: u8,
    gamepad_6: u8,
    gamepad_7: u8,
    gamepad_8: u8,
    gamepad_9: u8,
    gamepad_0: u8,
    gamepad_asterisk: u8,
    gamepad_hash: u8,
};

pub const Config = struct {
    input: [2]Input,

    pub fn init() !Config {
        const input_1 = Input{
            .left = SDL.SDL_SCANCODE_LEFT,
            .right = SDL.SDL_SCANCODE_RIGHT,
            .up = SDL.SDL_SCANCODE_UP,
            .down = SDL.SDL_SCANCODE_DOWN,
            .left_button = SDL.SDL_SCANCODE_A,
            .right_button = SDL.SDL_SCANCODE_S,
            .blue = SDL.SDL_SCANCODE_D,
            .purple = SDL.SDL_SCANCODE_F,
            .zero = SDL.SDL_SCANCODE_0,
            .one = SDL.SDL_SCANCODE_1,
            .two = SDL.SDL_SCANCODE_2,
            .three = SDL.SDL_SCANCODE_3,
            .four = SDL.SDL_SCANCODE_4,
            .five = SDL.SDL_SCANCODE_5,
            .six = SDL.SDL_SCANCODE_6,
            .seven = SDL.SDL_SCANCODE_7,
            .eight = SDL.SDL_SCANCODE_8,
            .nine = SDL.SDL_SCANCODE_9,
            .asterisk = SDL.SDL_SCANCODE_PERIOD,
            .hash = SDL.SDL_SCANCODE_RSHIFT,
            .gamepad = true,
            .gamepad_directional = 0,
            .gamepad_invert_x_axis = false,
            .gamepad_invert_y_axis = false,
            .gamepad_left_button = SDL.SDL_CONTROLLER_BUTTON_A,
            .gamepad_right_button = SDL.SDL_CONTROLLER_BUTTON_B,
            .gamepad_blue = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_purple = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_x_axis = 0,
            .gamepad_y_axis = 1,
            .gamepad_1 = SDL.SDL_CONTROLLER_BUTTON_X,
            .gamepad_2 = SDL.SDL_CONTROLLER_BUTTON_Y,
            .gamepad_3 = SDL.SDL_CONTROLLER_BUTTON_RIGHTSHOULDER,
            .gamepad_4 = SDL.SDL_CONTROLLER_BUTTON_LEFTSHOULDER,
            .gamepad_5 = SDL.SDL_CONTROLLER_BUTTON_RIGHTSTICK,
            .gamepad_6 = SDL.SDL_CONTROLLER_BUTTON_LEFTSTICK,
            .gamepad_7 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_8 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_9 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_0 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_asterisk = SDL.SDL_CONTROLLER_BUTTON_START,
            .gamepad_hash = SDL.SDL_CONTROLLER_BUTTON_BACK,
        };
        const input_2 = Input{
            .left = SDL.SDL_SCANCODE_J,
            .right = SDL.SDL_SCANCODE_L,
            .up = SDL.SDL_SCANCODE_I,
            .down = SDL.SDL_SCANCODE_K,
            .left_button = SDL.SDL_SCANCODE_G,
            .right_button = SDL.SDL_SCANCODE_H,
            .blue = SDL.SDL_SCANCODE_J,
            .purple = SDL.SDL_SCANCODE_K,
            .zero = SDL.SDL_SCANCODE_NONUSBACKSLASH,
            .one = SDL.SDL_SCANCODE_Z,
            .two = SDL.SDL_SCANCODE_X,
            .three = SDL.SDL_SCANCODE_C,
            .four = SDL.SDL_SCANCODE_V,
            .five = SDL.SDL_SCANCODE_B,
            .six = SDL.SDL_SCANCODE_N,
            .seven = SDL.SDL_SCANCODE_M,
            .eight = SDL.SDL_SCANCODE_COMMA,
            .nine = SDL.SDL_SCANCODE_PERIOD,
            .asterisk = SDL.SDL_SCANCODE_SLASH,
            .hash = SDL.SDL_SCANCODE_RSHIFT,
            .gamepad = true,
            .gamepad_directional = 0,
            .gamepad_invert_x_axis = false,
            .gamepad_invert_y_axis = false,
            .gamepad_left_button = SDL.SDL_CONTROLLER_BUTTON_A,
            .gamepad_right_button = SDL.SDL_CONTROLLER_BUTTON_B,
            .gamepad_blue = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_purple = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_x_axis = 0,
            .gamepad_y_axis = 1,
            .gamepad_1 = SDL.SDL_CONTROLLER_BUTTON_X,
            .gamepad_2 = SDL.SDL_CONTROLLER_BUTTON_Y,
            .gamepad_3 = SDL.SDL_CONTROLLER_BUTTON_RIGHTSHOULDER,
            .gamepad_4 = SDL.SDL_CONTROLLER_BUTTON_LEFTSHOULDER,
            .gamepad_5 = SDL.SDL_CONTROLLER_BUTTON_RIGHTSTICK,
            .gamepad_6 = SDL.SDL_CONTROLLER_BUTTON_LEFTSTICK,
            .gamepad_7 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_8 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_9 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_0 = SDL.SDL_CONTROLLER_BUTTON_GUIDE,
            .gamepad_asterisk = SDL.SDL_CONTROLLER_BUTTON_START,
            .gamepad_hash = SDL.SDL_CONTROLLER_BUTTON_BACK,
        };
        return .{
            .input = .{ input_1, input_2 },
        };
    }
};
