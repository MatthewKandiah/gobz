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

    const render_data1 = sprite_map.get(0, 0);
    const render_data2 = sprite_map.get(3, 4);
    const render_data3 = sprite_map.get(2, 20);

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

        // draw example images
        var output_idx1: usize = (pos_x + pos_y * surface_info.width_pixels);
        var count: usize = 0;
        for (0..render_data1.data.len / 4) |i| {
            const r = render_data1.data[4 * i];
            const g = render_data1.data[4 * i + 1];
            const b = render_data1.data[4 * i + 2];
            const a = render_data1.data[4 * i + 3];
    
            surface_info.bytes[4 * output_idx1] = b;
            surface_info.bytes[4 * output_idx1 + 1] = g;
            surface_info.bytes[4 * output_idx1 + 2] = r;
            surface_info.bytes[4 * output_idx1 + 3] = a;

            count += 1;
            output_idx1 += 1;
            if (count >= render_data1.width) {
                count = 0;
                output_idx1 += surface_info.width_pixels - render_data1.width;
            }
        }
        var output_idx2: usize = (pos_x + pos_y * surface_info.width_pixels + 64);
        var count2: usize = 0;
        for (0..render_data2.data.len / 4) |i| {
            const r = render_data2.data[4 * i];
            const g = render_data2.data[4 * i + 1];
            const b = render_data2.data[4 * i + 2];
            const a = render_data2.data[4 * i + 3];
    
            surface_info.bytes[4 * output_idx2] = b;
            surface_info.bytes[4 * output_idx2 + 1] = g;
            surface_info.bytes[4 * output_idx2 + 2] = r;
            surface_info.bytes[4 * output_idx2 + 3] = a;

            count2 += 1;
            output_idx2 += 1;
            if (count2 >= render_data2.width) {
                count2 = 0;
                output_idx2 += surface_info.width_pixels - render_data2.width;
            }
        }
        var output_idx3: usize = (pos_x + pos_y * surface_info.width_pixels + (2 * 32 * surface_info.width_pixels));
        var count3: usize = 0;
        for (0..render_data3.data.len / 4) |i| {
            const r = render_data3.data[4 * i];
            const g = render_data3.data[4 * i + 1];
            const b = render_data3.data[4 * i + 2];
            const a = render_data3.data[4 * i + 3];
    
            surface_info.bytes[4 * output_idx3] = b;
            surface_info.bytes[4 * output_idx3 + 1] = g;
            surface_info.bytes[4 * output_idx3 + 2] = r;
            surface_info.bytes[4 * output_idx3 + 3] = a;

            count3 += 1;
            output_idx3 += 1;
            if (count3 >= render_data3.width) {
                count3 = 0;
                output_idx3 += surface_info.width_pixels - render_data3.width;
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
                    c.SDLK_UP => pos_y -= 32,
                    c.SDLK_DOWN => pos_y += 32,
                    c.SDLK_LEFT => pos_x -= 32,
                    c.SDLK_RIGHT => pos_x += 32,
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
    height_sprites: usize,
    width_sprites: usize,
    bytes_per_pixel: usize,
    data: []u8,
    sprite_width_pixels: usize,
    sprite_height_pixels: usize,

    const Self = @This();

    fn load(allocator: std.mem.Allocator, path: []const u8, sprite_width_pixels: usize, sprite_height_pixels: usize) !Self {
        var input_width: c_int = undefined;
        var input_height: c_int = undefined;
        var input_bytes_per_pixel: c_int = undefined;
        var input_data: [*]u8 = undefined;
        input_data = c.stbi_load(@ptrCast(path), &input_width, &input_height, &input_bytes_per_pixel, 0);
        defer c.stbi_image_free(input_data);

        std.debug.assert(input_bytes_per_pixel == 4);
        const height_pixels: usize = @intCast(input_height);
        const width_pixels: usize = @intCast(input_width);
        const sprite_column_count = width_pixels / sprite_width_pixels;
        const sprite_row_count = height_pixels / sprite_height_pixels;
        const output_data = try allocator.alloc(u8, @intCast(input_width * input_height * 4));
        var output_idx: usize = 0;
        for (0..sprite_row_count) |sprite_row_idx| {
            for (0..sprite_column_count) |sprite_col_idx| {
                const sprite_data_top_left_idx = ((sprite_row_idx * sprite_height_pixels * width_pixels) + (sprite_col_idx * sprite_width_pixels)) * 4;
                for (0..sprite_height_pixels) |j| {
                    for (0..sprite_width_pixels * 4) |i| {
                        const input_data_idx = sprite_data_top_left_idx + (j * width_pixels * 4) + i;
                        output_data[output_idx] = input_data[input_data_idx];
                        output_idx += 1;
                    }
                }
            }
        }
        std.debug.assert(output_idx == input_width * input_height * input_bytes_per_pixel);

        return SpriteMap{
            .height_sprites = sprite_row_count,
            .width_sprites = sprite_column_count,
            .bytes_per_pixel = @intCast(input_bytes_per_pixel),
            .data = output_data,
            .sprite_width_pixels = sprite_width_pixels,
            .sprite_height_pixels = sprite_height_pixels,
        };
    }

    fn get(self: Self, x_idx: usize, y_idx: usize) RenderInfo {
        const start_idx = 4 * ((x_idx * self.sprite_width_pixels) + (y_idx * self.sprite_height_pixels * self.width_sprites * self.sprite_width_pixels));
        const byte_count = self.sprite_width_pixels * self.sprite_height_pixels * 4;
        return RenderInfo{
            .width = self.sprite_width_pixels,
            .data = self.data[start_idx .. start_idx + byte_count],
        };
    }
};
