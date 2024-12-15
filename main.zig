const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("stb_image.h");
});

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 600;

pub fn main() void {
    // load image into memory
    var input_width_raw: c_int = undefined;
    var input_height_raw: c_int = undefined;
    var input_bytes_per_pixel: c_int = undefined;
    var input_data: [*]u8 = undefined;
    input_data = c.stbi_load(@ptrCast("./sprites/vampire.png"), &input_width_raw, &input_height_raw, &input_bytes_per_pixel, 0);
    const input_width: usize = @intCast(input_width_raw);
    const input_height: usize = @intCast(input_height_raw);

    // set up window
    const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS);
    if (sdl_init != 0) {
        std.debug.panic("SDL_Init failed: {}\n", .{sdl_init});
    }

    const window: *c.SDL_Window = c.SDL_CreateWindow(
        "Gobz",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        DEFAULT_WIDTH,
        DEFAULT_HEIGHT,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse @panic("no window");

    var surface_info = getSurfaceInfo(window);
    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        // clear screen
        for (surface_info.bytes) |*p| {
            p.* = 122;
        }

        std.debug.assert(input_bytes_per_pixel == 4);
        std.debug.assert(input_height < surface_info.height_pixels);
        std.debug.assert(input_width < surface_info.width_pixels);
        // draw example image
        for (0..input_height) |j| {
            for (0 .. input_width * 4) |i| {
                const input_byte_index = j * input_width * 4 + i;
                const surface_byte_index = j * surface_info.width_pixels * 4 + i;
                surface_info.bytes[surface_byte_index] = input_data[input_byte_index];
            }
        }

        // handle events
        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    else => {},
                }
            }
            if (event.type == c.SDL_WINDOWEVENT) {
                // handle window resizing
                surface_info = getSurfaceInfo(window);
            }
        }

        if (c.SDL_UpdateWindowSurface(window) < 0) {
            @panic("Couldn't update window surface");
        }
    }
}

const Surface = struct {
    bytes: []u8,
    width_pixels: usize,
    height_pixels: usize,
};

fn getSurfaceInfo(window: *c.SDL_Window) Surface {
    const surface: *c.SDL_Surface = c.SDL_GetWindowSurface(window) orelse std.debug.panic("No surface\n", .{});
    const width: usize = @intCast(surface.w);
    const height: usize = @intCast(surface.h);
    const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("No pixels"));
    const pixels_count = 4 * width * height;
    const bytes = pixels[0..pixels_count];
    return .{ .bytes = bytes, .width_pixels = width, .height_pixels = height };
}
