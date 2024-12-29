const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const SpriteMap = @import("sprite_map.zig").SpriteMap;
const Surface = @import("surface.zig").Surface;
const RenderInfo = @import("render_info.zig").RenderInfo;
const Map = @import("map.zig").Map;
const MapValue = @import("map_value.zig").MapValue;
const GameState = @import("game_state.zig").GameState;
const Dim = @import("dim.zig").Dim;
const Pos = @import("pos.zig").Pos;
const Disp = @import("disp.zig").Disp;
const Pixel = @import("pixel.zig").Pixel;
const Rect = @import("rect.zig").Rect;

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;
const INPUT_SPRITE_WIDTH = 32;
const INPUT_SPRITE_HEIGHT = 32;
const MAX_SCALE = 5;
const CLEAR_VALUE = 0;

// TODO - performance monitoring, cpu cycles and wall clock time per frame

pub fn main() !void {
    var scale: usize = 2;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const rng_seed = std.time.timestamp();
    var rng = std.Random.DefaultPrng.init(@intCast(rng_seed));
    const random = rng.random();
    // setup map
    const map_dim_tiles = Dim{
        .width = 200,
        .height = 100,
    };
    const map_tile_count = map_dim_tiles.width * map_dim_tiles.height;
    var map_data: [map_tile_count]MapValue = .{.Wall} ** map_tile_count;
    const max_room_dim_tiles = Dim{ .width = 9, .height = 9 };
    const min_room_dim_tiles = Dim{ .width = 3, .height = 3 };
    const room_count = 50;
    // add rooms
    var rooms: [room_count]Rect = undefined;
    for (0..room_count) |n| {
        const room_dim_tiles = Dim{
            .width = random.intRangeAtMost(usize, min_room_dim_tiles.width, max_room_dim_tiles.width),
            .height = random.intRangeAtMost(usize, min_room_dim_tiles.height, max_room_dim_tiles.height),
        };
        const room_pos = Pos{
            .x = random.intRangeAtMost(usize, 1, map_dim_tiles.width - 1 - room_dim_tiles.width),
            .y = random.intRangeAtMost(usize, 1, map_dim_tiles.height - 1 - room_dim_tiles.height),
        };
        rooms[n] = Rect{ .pos = room_pos, .dim = room_dim_tiles };
        for (0..room_dim_tiles.height) |j| {
            for (0..room_dim_tiles.width) |i| {
                map_data[room_pos.x + i + (room_pos.y + j) * map_dim_tiles.width] = .Floor;
            }
        }
        // add corridors
        if (n != 0) {
            const start_point = Pos{
                .x = random.intRangeLessThan(usize, rooms[n].pos.x, rooms[n].pos.x + rooms[n].dim.width),
                .y = random.intRangeLessThan(usize, rooms[n].pos.y, rooms[n].pos.y + rooms[n].dim.height),
            };
            const end_point = Pos{
                .x = random.intRangeLessThan(usize, rooms[n - 1].pos.x, rooms[n - 1].pos.x + rooms[n - 1].dim.width),
                .y = random.intRangeLessThan(usize, rooms[n - 1].pos.y, rooms[n - 1].pos.y + rooms[n - 1].dim.height),
            };
            const min_x = @min(start_point.x, end_point.x);
            const max_x = @max(start_point.x, end_point.x);
            const min_y = @min(start_point.y, end_point.y);
            const max_y = @max(start_point.y, end_point.y);
            for (min_x..max_x + 1) |x| {
                map_data[x + start_point.y * map_dim_tiles.width] = .Floor;
            }
            for (min_y..max_y + 1) |y| {
                map_data[end_point.x + y * map_dim_tiles.width] = .Floor;
            }
        }
    }

    const map = Map{
        .data = &map_data,
        .dim_tiles = map_dim_tiles,
    };

    // assets from https://sethbb.itch.io/32rogues
    const animals_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/animals.png", INPUT_SPRITE_WIDTH, INPUT_SPRITE_HEIGHT, Pixel{ .a = 0 });
    const items_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/items.png", INPUT_SPRITE_WIDTH, INPUT_SPRITE_HEIGHT, Pixel{ .a = 0 });
    const monsters_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/monsters.png", INPUT_SPRITE_WIDTH, INPUT_SPRITE_HEIGHT, Pixel{ .a = 0 });
    const rogues_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/rogues.png", INPUT_SPRITE_WIDTH, INPUT_SPRITE_HEIGHT, Pixel{ .a = 0 });
    const tiles_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/tiles.png", INPUT_SPRITE_WIDTH, INPUT_SPRITE_HEIGHT, Pixel{ .a = 0 });

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
    _ = wall_tile_render_data;
    const floor_tile_render_data = tiles_sprite_map.get(0, 1);

    var surface_info = getSurface(window);
    var running = true;
    var event: c.SDL_Event = undefined;
    var game_state = GameState{
        .player_pos = rooms[0].pos,
        .map = map,
    };

    while (running) {
        const sprite_width = INPUT_SPRITE_WIDTH * scale;
        const sprite_height = INPUT_SPRITE_HEIGHT * scale;

        // clear screen
        for (surface_info.bytes) |*p| {
            p.* = CLEAR_VALUE;
        }

        // draw map
        const clipping_rect = Rect{
            .dim = Dim{ .width = surface_info.width_pixels, .height = surface_info.height_pixels },
            .pos = Pos{ .x = 0, .y = 0 },
        };
        const player_sprite_pos = .{
            .x = clipping_rect.pos.x + clipping_rect.dim.width / 2 - sprite_width / 2,
            .y = clipping_rect.pos.y + clipping_rect.dim.height / 2 - sprite_height / 2,
        };
        for (0..map.dim_tiles.height) |j| {
            for (0..map.dim_tiles.width) |i| {
                const map_cell = map.get(Pos{.x = i, .y = j}) orelse @panic("should never happen");
                const maybe_render_data = switch (map_cell) {
                    .Clear => null,
                    .Floor => floor_tile_render_data,
                    .Wall => null,
                };
                if (maybe_render_data) |render_data| {
                    const ax = player_sprite_pos.x + i * sprite_width;
                    const bx = game_state.player_pos.x * sprite_width;
                    const ay = player_sprite_pos.y + j * sprite_height;
                    const by = game_state.player_pos.y * sprite_height;
                    if (ax >= bx and ay >= by) {
                        const x_idx = player_sprite_pos.x + i * sprite_width - game_state.player_pos.x * sprite_width;
                        const y_idx = player_sprite_pos.y + j * sprite_height - game_state.player_pos.y * sprite_height;
                        if (x_idx + sprite_width < surface_info.width_pixels and y_idx + sprite_height < surface_info.height_pixels) {
                            surface_info.draw(
                                render_data,
                                .{ .x = x_idx, .y = y_idx },
                                clipping_rect,
                                scale,
                                null,
                            );
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
            scale,
            .{ .r = 255, .g = 255, .b = 0 },
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
                    c.SDLK_MINUS => zoomOut(&scale),
                    c.SDLK_EQUALS => zoomIn(&scale),
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

fn zoomIn(scale: *usize) void {
    if (scale.* >= MAX_SCALE) return;
    scale.* += 1;
}

fn zoomOut(scale: *usize) void {
    if (scale.* == 1) return;
    scale.* -= 1;
}

fn getSurface(window: *c.SDL_Window) Surface {
    const surface: *c.SDL_Surface = c.SDL_GetWindowSurface(window) orelse std.debug.panic("No surface\n", .{});
    const width: usize = @intCast(surface.w);
    const height: usize = @intCast(surface.h);
    const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("No pixels"));
    const pixels_count = 4 * width * height;
    const bytes = pixels[0..pixels_count];

    const pixel_format = .{
        .r = maskToIndex(surface.format.*.Rmask),
        .g = maskToIndex(surface.format.*.Gmask),
        .b = maskToIndex(surface.format.*.Bmask),
        .a = maskToIndex(surface.format.*.Amask),
    };
    return .{ .bytes = bytes, .width_pixels = width, .height_pixels = height, .pixel_format = pixel_format };
}

fn maskToIndex(mask: u32) usize {
    if (mask == 0x00_00_00_ff) {
        return 0;
    } else if (mask == 0x00_00_ff_00) {
        return 1;
    } else if (mask == 0x00_ff_00_00) {
        return 2;
    } else if (mask == 0xff_00_00_00) {
        return 3;
    } else {
        return 3; // turns out the alpha channel on my laptop is 0
    }
    unreachable;
}

test {
    _ = @import("tests/drawing.zig");
    std.testing.refAllDecls(@This());
}
