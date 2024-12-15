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

    const window: *c.SDL_Window = c.SDL_CreateWindow(
        "Gobz",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        WIDTH,
        HEIGHT,
        0,//c.SDL_WINDOW_RESIZABLE,
    ) orelse @panic("no window");

    const surface: *c.SDL_Surface = c.SDL_GetWindowSurface(window) orelse std.debug.panic("No surface\n", .{});
    const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("No pixels"));
    const pixels_count = 4 * WIDTH * HEIGHT;
    const pixels_slice = pixels[0..pixels_count];
    for (pixels_slice) |*p| {
        p.* = 122;
    }
    if (c.SDL_UpdateWindowSurface(window) < 0) {
        @panic("Couldn't update window surface");
    }

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
