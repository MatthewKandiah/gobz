const std = @import("std");
const c = @cImport(
    @cInclude("SDL2/SDL.h"),
);

const WIDTH = 800;
const HEIGHT = 600;

pub fn main() void {
    const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS);
    if (sdl_init != 0) {
        std.debug.panic("SDL_Init failed: {}\n", .{sdl_init});
    }

    const window = c.SDL_CreateWindow(
        "Gobz",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        WIDTH,
        HEIGHT,
        c.SDL_WINDOW_RESIZABLE,
    );

    const surface = c.SDL_GetWindowSurface(window);
    _ = surface;

    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }
        }
    }
}
