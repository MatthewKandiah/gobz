const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const SpriteMap = @import("sprite_map.zig").SpriteMap;
const Surface = @import("surface.zig").Surface;
const RenderInfo = @import("render_info.zig").RenderInfo;

pub const Dim = struct { w: usize, h: usize };
pub const Pos = struct { x: usize, y: usize };
pub const Rect = struct {
    d: Dim,
    p: Pos,

    const Self = @This();

    pub fn contains(self: Self, pos: Pos) bool {
        return (pos.x >= self.p.x and pos.x < self.p.x + self.d.w) and (pos.y >= self.p.y and pos.y < self.p.y + self.d.h);
    }
};

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;
const SPRITE_WIDTH = 32;
const SPRITE_HEIGHT = 32;

// TODO - make the map much bigger, then render only what "fits on screen"
// TODO - move player around and centre viewport on them
// TODO - allow zooming in and out by scaling sprites
// TODO - using sprite render info as stencil / mask instead of just drawing the entire square every time
// TODO - get SDL surface pixel format and ensure we're writing our RGBA data to the surface in the format it's expecting

pub const MapValue = enum {
    Clear,
    Floor,
    Wall,
};

pub const Map = struct {
    data: []const MapValue,
    height: usize,
    width: usize,

    const Self = @This();

    pub fn get(self: Self, x: usize, y: usize) ?MapValue {
        if (x >= self.width or y >= self.height) {
            return null;
        }
        return self.data[y * self.width + x];
    }
};

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

const map = Map{
    .data = &map_data,
    .width = 9,
    .height = 9,
};

pub const GameState = struct {
    player_pos_x: usize,
    player_pos_y: usize,
    map: Map,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // assets from https://sethbb.itch.io/32rogues
    const animals_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/animals.png", SPRITE_WIDTH, SPRITE_HEIGHT);
    const items_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/items.png", SPRITE_WIDTH, SPRITE_HEIGHT);
    const monsters_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/monsters.png", SPRITE_WIDTH, SPRITE_HEIGHT);
    const rogues_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/rogues.png", SPRITE_WIDTH, SPRITE_HEIGHT);
    const tiles_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/tiles.png", SPRITE_WIDTH, SPRITE_HEIGHT);

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
    const wall_tile_render_data = tiles_sprite_map.get(0, 0);
    const floor_tile_render_data = tiles_sprite_map.get(0, 1);

    var surface_info = getSurface(window);
    var running = true;
    var event: c.SDL_Event = undefined;
    var game_state = GameState{
        .player_pos_x = 1,
        .player_pos_y = 1,
        .map = map,
    };

    while (running) {
        // clear screen
        for (surface_info.bytes) |*p| {
            p.* = 122;
        }

        // TODO - move map and keep player sprite centred
        // draw map
        const map_pos = .{ .x = 16, .y = 48 };
        const clipping_rect = Rect{ .d = .{ .w = 3.5 * SPRITE_WIDTH, .h = 3.5 * SPRITE_HEIGHT }, .p = map_pos };
        for (0..map.height) |j| {
            for (0..map.width) |i| {
                const map_cell = map.get(i, j) orelse .Clear;
                const maybe_render_data = switch (map_cell) {
                    .Clear => null,
                    .Floor => floor_tile_render_data,
                    .Wall => wall_tile_render_data,
                };
                if (maybe_render_data) |render_data| {
                    const x_idx = map_pos.x + i * SPRITE_WIDTH;
                    const y_idx = map_pos.y + j * SPRITE_HEIGHT;
                    surface_info.drawWithClipping(render_data, x_idx, y_idx, clipping_rect);
                }
            }
        }

        // draw player
        surface_info.drawWithClipping(
            rogue_render_data,
            map_pos.x + game_state.player_pos_x * SPRITE_WIDTH,
            map_pos.y + game_state.player_pos_y * SPRITE_HEIGHT,
            clipping_rect,
        );

        // handle events
        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    c.SDLK_UP => handleMove(&game_state, 0, -1),
                    c.SDLK_DOWN => handleMove(&game_state, 0, 1),
                    c.SDLK_LEFT => handleMove(&game_state, -1, 0),
                    c.SDLK_RIGHT => handleMove(&game_state, 1, 0),
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

fn handleMove(game_state: *GameState, dx: i32, dy: i32) void {
    var new_player_x: usize = game_state.player_pos_x;
    var new_player_y: usize = game_state.player_pos_y;
    if (@as(i32, @intCast(game_state.player_pos_x)) + dx >= 0) {
        new_player_x = @intCast(@as(i32, @intCast(game_state.player_pos_x)) + dx);
    }
    if (@as(i32, @intCast(game_state.player_pos_y)) + dy >= 0) {
        new_player_y = @intCast(@as(i32, @intCast(game_state.player_pos_y)) + dy);
    }
    if (game_state.map.get(new_player_x, new_player_y) != .Wall) {
        game_state.*.player_pos_x = new_player_x;
        game_state.*.player_pos_y = new_player_y;
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