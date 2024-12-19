const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const SpriteMap = @import("sprite_map.zig").SpriteMap;
const Surface = @import("surface.zig").Surface;

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;

// TODO - make the map much bigger, then render only what "fits on screen"
// TODO - move player around and centre viewport on them
// TODO - allow zooming in and out by scaling sprites
// TODO - using sprite render info as stencil / mask instead of just drawing the entire square every time
// TODO - get SDL surface pixel format and ensure we're writing our RGBA data to the surface in the format it's expecting

pub const MapValue = enum {
    Floor,
    Wall,
};

pub const Map = struct {
    data: []const MapValue,
    width: usize,
    height: usize,
};

const map_width = 9;
const map_height = 9;
const map_data = [_]MapValue{
    .Wall, .Wall,  .Wall,  .Wall,  .Wall,  .Wall,  .Wall,  .Wall,  .Wall,
    .Wall, .Floor, .Wall,  .Floor, .Wall,  .Floor, .Wall,  .Floor, .Wall,
    .Wall, .Floor, .Wall,  .Wall,  .Floor, .Wall,  .Wall,  .Floor, .Wall,
    .Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
    .Wall, .Wall,  .Floor, .Wall,  .Wall,  .Wall,  .Floor, .Wall,  .Wall,
    .Wall, .Wall,  .Floor, .Wall,  .Wall,  .Wall,  .Floor, .Wall,  .Wall,
    .Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
    .Wall, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Floor, .Wall,
    .Wall, .Wall,  .Wall,  .Wall,  .Wall,  .Wall,  .Wall,  .Wall,  .Wall,
};

// define the space on screen that the grid will actually be rendered in
// may need to assert on its dimensions to ensure sensible centering?
// will need to rethink drawing a lŧtle as well, do we want to create a render info for the whole grid out of the render info for each tile?
// or do we give GameRenderArea a draw function and pass in the surface? So this struct can just draw itself onto the surface using its draw function
// maybe that's a good pattern to follow? Game entities have a way to produce a render data, UI components have a function that takes a surface and draws themself at a position
// TODO - resizing on window resize?
const GameRenderArea = struct {
    pos_x_pixels: usize,
    pos_y_pixels: usize,
    width_pixels: usize,
    height_pixels: usize,
};

pub const GameState = struct {
    player_pos_x: usize,
    player_pos_y: usize,
    // game_render_area: GameRenderArea,
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
    var game_state = GameState {
        .player_pos_x = 0,
        .player_pos_y = 0,
    };
    while (running) {
        // clear screen
        for (surface_info.bytes) |*p| {
            p.* = 122;
        }

        // draw map
        for (0..map_height) |j| {
            for (0..map_width) |i| {
                const map_cell = map_data[i + map_width*j];
                const maybe_render_data = switch (map_cell) {
                    .Floor => null,
                    .Wall => tile_render_data,
                };
                if (maybe_render_data) |render_data| {
                    const x_idx = i * 32;
                    const y_idx = j * 32;
                    surface_info.draw(render_data, x_idx, y_idx);
                }
            }
        }

        // draw player
        surface_info.draw(rogue_render_data, game_state.player_pos_x, game_state.player_pos_y);

        // handle events
        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    c.SDLK_UP => game_state.player_pos_y -= 32,
                    c.SDLK_DOWN => game_state.player_pos_y += 32,
                    c.SDLK_LEFT => game_state.player_pos_x -= 32,
                    c.SDLK_RIGHT => game_state.player_pos_x += 32,
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

fn getSurface(window: *c.SDL_Window) Surface {
    const surface: *c.SDL_Surface = c.SDL_GetWindowSurface(window) orelse std.debug.panic("No surface\n", .{});
    const width: usize = @intCast(surface.w);
    const height: usize = @intCast(surface.h);
    const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("No pixels"));
    const pixels_count = 4 * width * height;
    const bytes = pixels[0..pixels_count];
    return .{ .bytes = bytes, .width_pixels = width, .height_pixels = height };
}
