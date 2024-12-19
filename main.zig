const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("stb_image.h");
});

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;

// TODO - make the map much bigger, then render only what "fits on screen"
// TODO - move player around and centre viewport on them
// TODO - allow zooming in and out by scaling sprites
// TODO - using sprite render info as stencil / mask instead of just drawing the entire square every time

const map = [_][]const u32{
    &[_]u32{ 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    &[_]u32{ 1, 0, 1, 0, 1, 0, 1, 0, 1 },
    &[_]u32{ 1, 0, 1, 1, 0, 1, 1, 0, 1 },
    &[_]u32{ 1, 0, 0, 0, 0, 0, 0, 0, 1 },
    &[_]u32{ 1, 1, 0, 1, 1, 1, 0, 1, 1 },
    &[_]u32{ 1, 1, 0, 1, 1, 1, 0, 1, 1 },
    &[_]u32{ 1, 0, 0, 0, 0, 0, 0, 0, 1 },
    &[_]u32{ 1, 0, 0, 0, 0, 0, 0, 0, 1 },
    &[_]u32{ 1, 1, 1, 1, 1, 1, 1, 1, 1 },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // assets from https://sethbb.itch.io/32rogues
    const animals_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/animals.png", 32, 32);
    const items_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/items.png", 32, 32);
    const monsters_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/monsters.png", 32, 32);
    const rogues_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/rogues.png", 32, 32);
    const tiles_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/tiles.png", 32, 32);

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

    const animal_render_data = animals_sprite_map.get(0, 0);
    const item_render_data = items_sprite_map.get(0, 0);
    const monster_render_data = monsters_sprite_map.get(0, 0);
    _ = animal_render_data;
    _ = item_render_data;
    _ = monster_render_data;
    const rogue_render_data = rogues_sprite_map.get(0, 0);
    const tile_render_data = tiles_sprite_map.get(0, 0);

    var surface_info = getSurface(window);
    var running = true;
    var event: c.SDL_Event = undefined;
    var player_pos_x: usize = 0;
    var player_pos_y: usize = 0;
    while (running) {
        // clear screen
        for (surface_info.bytes) |*p| {
            p.* = 122;
        }

        // draw map
        for (map, 0..) |map_row, j| {
            for (map_row, 0..) |map_cell, i| {
                const maybe_render_data = switch (map_cell) {
                    0 => null,
                    1 => tile_render_data,
                    else => return error.UnexpectedMapValue,
                };
                if (maybe_render_data) |render_data| {
                    const x_idx = i * 32;
                    const y_idx = j * 32;
                    surface_info.draw(render_data, x_idx, y_idx);
                }
            }
        }

        // draw player
        surface_info.draw(rogue_render_data, player_pos_x, player_pos_y);

        // handle events
        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    c.SDLK_UP => player_pos_y -= 32,
                    c.SDLK_DOWN => player_pos_y += 32,
                    c.SDLK_LEFT => player_pos_x -= 32,
                    c.SDLK_RIGHT => player_pos_x += 32,
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

    const Self = @This();

    fn draw(self: Self, render_info: RenderInfo, pos_x: usize, pos_y: usize) void {
        var output_idx: usize = pos_x + pos_y * self.width_pixels;
        var count: usize = 0;
        for (0..render_info.data.len / 4) |i| {
            const r = render_info.data[4 * i];
            const g = render_info.data[4 * i + 1];
            const b = render_info.data[4 * i + 2];
            const a = render_info.data[4 * i + 3];

            self.bytes[4 * output_idx] = b;
            self.bytes[4 * output_idx + 1] = g;
            self.bytes[4 * output_idx + 2] = r;
            self.bytes[4 * output_idx + 3] = a;

            count += 1;
            output_idx += 1;
            if (count >= render_info.width) {
                count = 0;
                output_idx += self.width_pixels - render_info.width;
            }
        }
    }
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
