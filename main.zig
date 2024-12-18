const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("stb_image.h");
});

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const sprite_map = try SpriteMap.load(allocator, "./sprites/character32x32.png", 32, 32);

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

    var surface_info = getSurface(window);
    var running = true;
    var event: c.SDL_Event = undefined;
    var pos_x: usize = 0;
    var pos_y: usize = 0;
    while (running) {
        // clear screen
        for (surface_info.bytes) |*p| {
            p.* = 122;
        }

        std.debug.assert(sprite_map.height < surface_info.height_pixels);
        std.debug.assert(sprite_map.width < surface_info.width_pixels);
        // draw example image
        for (0..sprite_map.height) |j| {
            for (0..sprite_map.width * 4) |i| {
                const input_byte_index = j * sprite_map.width * 4 + i;
                const surface_byte_index = (j + pos_y) * surface_info.width_pixels * 4 + (i + 4 * pos_x);
                surface_info.bytes[surface_byte_index] = sprite_map.data[input_byte_index];
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
                    c.SDLK_UP => pos_y -= 1,
                    c.SDLK_DOWN => pos_y += 1,
                    c.SDLK_LEFT => pos_x -= 1,
                    c.SDLK_RIGHT => pos_x += 1,
                    else => {},
                }
            }
            if (event.type == c.SDL_WINDOWEVENT) {
                // handle window resizing
                surface_info = getSurface(window);
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

fn getSurface(window: *c.SDL_Window) Surface {
    const surface: *c.SDL_Surface = c.SDL_GetWindowSurface(window) orelse std.debug.panic("No surface\n", .{});
    const width: usize = @intCast(surface.w);
    const height: usize = @intCast(surface.h);
    const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("No pixels"));
    const pixels_count = 4 * width * height;
    const bytes = pixels[0..pixels_count];
    return .{ .bytes = bytes, .width_pixels = width, .height_pixels = height };
}

const RenderInfo = struct {
    width: usize,
    data: []u8,
};

const SpriteMap = struct {
    height: usize,
    width: usize,
    bytes_per_pixel: usize,
    data: []u8,
    sprite_width: usize,
    sprite_height: usize,

    const Self = @This();

    fn load(allocator: std.mem.Allocator, path: []const u8, sprite_width: usize, sprite_height: usize) !Self {
        var input_width: c_int = undefined;
        var input_height: c_int = undefined;
        var input_bytes_per_pixel: c_int = undefined;
        var input_data: [*]u8 = undefined;
        input_data = c.stbi_load(@ptrCast(path), &input_width, &input_height, &input_bytes_per_pixel, 0);
        std.debug.assert(input_bytes_per_pixel == 4);
        defer c.stbi_image_free(input_data);
        // TODO - rearrange this data so that each sprite can be referred to as a contiguous block in memory
        const output_data = try allocator.alloc(u8, @intCast(input_width * input_height * 4));
        std.mem.copyForwards(u8, output_data, input_data[0..@intCast(input_width * input_height * 4)]);
        return SpriteMap{
            .height = @intCast(input_height),
            .width = @intCast(input_width),
            .bytes_per_pixel = @intCast(input_bytes_per_pixel),
            .data = output_data,
            .sprite_width = sprite_width,
            .sprite_height = sprite_height,
        };
    }

    // Pick a sprite by position in the sheet and get info to render it on screen
    fn get(x_index: usize, y_index: usize) RenderInfo {
        _ = x_index;
        _ = y_index;
        @panic("Not implemented");
    }
};
