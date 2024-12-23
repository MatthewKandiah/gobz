const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const SpriteMap = @import("sprite_map.zig").SpriteMap;
const Surface = @import("surface.zig").Surface;
const RenderInfo = @import("render_info.zig").RenderInfo;
const Map = @import("map.zig").Map;
const MapValue = @import("map.zig").MapValue;
const GameState = @import("game_state.zig").GameState;

pub const Dim = struct { width: usize, height: usize };
pub const Pos = struct { x: usize, y: usize };
pub const Disp = struct { dx: i32, dy: i32 };
pub const Rect = struct {
    dim: Dim,
    pos: Pos,

    const Self = @This();

    pub fn contains(self: Self, pos: Pos) bool {
        return (pos.x >= self.pos.x and pos.x < self.pos.x + self.dim.width) and (pos.y >= self.pos.y and pos.y < self.pos.y + self.dim.height);
    }
};

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;
const SPRITE_WIDTH = 32;
const SPRITE_HEIGHT = 32;

// TODO - allow zooming in and out by scaling sprites
// TODO - using sprite render info as stencil / mask instead of just drawing the entire square every time
// TODO - get SDL surface pixel format and ensure we're writing our RGBA data to the surface in the format it's expecting

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // setup map
    const map_width = 200;
    const map_height = 200;
    var map_data: [map_width * map_height]MapValue = undefined;
    for (&map_data, 0..) |*m, i| {
        if (i % 10 == 0) {
            m.* = .Wall;
        } else {
            m.* = .Floor;
        }
    }
    const map = Map{
        .data = &map_data,
        .width = map_width,
        .height = map_height,
    };

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
        .player_pos = Pos{ .x = 0, .y = 0 },
        .map = map,
    };

    while (running) {
        // clear screen
        for (surface_info.bytes) |*p| {
            p.* = 122;
        }

        // draw map
        // const clipping_rect = Rect{
        //     .dim = Dim{ .width = surface_info.width_pixels * 4 / 5, .height = surface_info.height_pixels },
        //     .pos = Pos{ .x = 16, .y = 16 },
        // };
        const clipping_rect = Rect{
            .dim = Dim{ .width = surface_info.width_pixels, .height = surface_info.height_pixels },
            .pos = Pos{ .x = 0, .y = 0 },
        };
        const player_sprite_pos = .{
            .x = clipping_rect.pos.x + clipping_rect.dim.width / 2 - SPRITE_WIDTH / 2,
            .y = clipping_rect.pos.y + clipping_rect.dim.height / 2 - SPRITE_HEIGHT / 2,
        };
        for (0..map.height) |j| {
            for (0..map.width) |i| {
                const map_cell = map.get(i, j) orelse @panic("should never happen");
                const maybe_render_data = switch (map_cell) {
                    .Clear => null,
                    .Floor => floor_tile_render_data,
                    .Wall => wall_tile_render_data,
                };
                if (maybe_render_data) |render_data| {
                    const ax = player_sprite_pos.x + i * SPRITE_WIDTH;
                    const bx = game_state.player_pos.x * SPRITE_WIDTH;
                    const ay = player_sprite_pos.y + j * SPRITE_HEIGHT;
                    const by = game_state.player_pos.y * SPRITE_HEIGHT;
                    if (ax >= bx and ay >= by) {
                        const x_idx = player_sprite_pos.x + i * SPRITE_WIDTH - game_state.player_pos.x * SPRITE_WIDTH;
                        const y_idx = player_sprite_pos.y + j * SPRITE_HEIGHT - game_state.player_pos.y * SPRITE_HEIGHT;
                        if (x_idx + SPRITE_WIDTH < surface_info.width_pixels and y_idx + SPRITE_HEIGHT < surface_info.height_pixels) {
                            surface_info.draw(render_data, .{ .x = x_idx, .y = y_idx }, clipping_rect);
                        }
                    }
                }
            }
        }

        // draw player
        surface_info.draw(
            rogue_render_data,
            .{ .x = player_sprite_pos.x, .y = player_sprite_pos.y },
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
                    c.SDLK_UP => game_state.handleMove(Disp{ .dx = 0, .dy = -1 }),
                    c.SDLK_DOWN => game_state.handleMove(Disp{ .dx = 0, .dy = 1 }),
                    c.SDLK_LEFT => game_state.handleMove(Disp{ .dx = -1, .dy = 0 }),
                    c.SDLK_RIGHT => game_state.handleMove(Disp{ .dx = 1, .dy = 0 }),
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
