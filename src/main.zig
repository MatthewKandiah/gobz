const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const SpriteMap = @import("sprite_map.zig").SpriteMap;
const Surface = @import("surface.zig").Surface;
const Map = @import("map.zig").Map;
const MapValue = @import("map_value.zig").MapValue;
const GameState = @import("game_state.zig").GameState;
const Dim = @import("dim.zig").Dim;
const Pos = @import("pos.zig").Pos;
const Disp = @import("disp.zig").Disp;
const Pixel = @import("pixel.zig").Pixel;
const Rect = @import("rect.zig").Rect;
const VisibilityValue = @import("visibility_value.zig").VisibilityValue;
const Profiler = @import("profiler.zig").Profiler;
const EnemyState = @import("enemy_state.zig").EnemyState;
const EnemyType = @import("enemy_type.zig").EnemyType;
const EnemyRace = @import("enemy_race.zig").EnemyRace;
const DenseRenderInfo = @import("render_info.zig").DenseRenderInfo;
const Colour = @import("colour.zig").Colour;

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;
const INPUT_SPRITE_DIM_PIXELS = .{ .width = 32, .height = 32 };
const MAX_SCALE = 5;
const PLAYER_VIEW_RANGE = 8;
const MAP_WIDTH = 200;
const MAP_HEIGHT = 100;
pub const MAP_MAX_DIMENSION = @max(MAP_WIDTH, MAP_HEIGHT);

// TODO - font sprite sheet
// TODO - render text box

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var profiler = Profiler.init(allocator);

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

    var visibility_data = [_]VisibilityValue{.Unknown} ** map_tile_count;

    const map = Map{
        .data = &map_data,
        .visibility = &visibility_data,
        .dim_tiles = map_dim_tiles,
    };

    // assets from https://sethbb.itch.io/32rogues
    const rogues_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/rogues.png", INPUT_SPRITE_DIM_PIXELS, Pixel{ .a = 0 });
    const rogues_dense_sprite_map = try rogues_sprite_map.toDense(allocator);
    // TODO - way to just fill a rect
    const tiles_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/tiles.png", INPUT_SPRITE_DIM_PIXELS, Pixel{ .a = 0 });
    const monsters_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/monsters.png", INPUT_SPRITE_DIM_PIXELS, Pixel{ .a = 0 });
    const monsters_dense_sprite_map = try monsters_sprite_map.toDense(allocator);
    const animals_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/animals.png", INPUT_SPRITE_DIM_PIXELS, Pixel{ .a = 0 });
    const animals_dense_sprite_map = try animals_sprite_map.toDense(allocator);

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

    // TODO - can this all move to comptime? Then these can be methods on the enum
    const rogue_render_data = rogues_dense_sprite_map.get(.{ .x = 0, .y = 0 });
    const floor_tile_render_data = tiles_sprite_map.get(.{ .x = 0, .y = 1 });
    const enemy_type_render_info_lookup: [std.meta.fields(EnemyType).len]DenseRenderInfo = .{
        monsters_dense_sprite_map.get(.{ .x = 0, .y = 0 }), // Warrior
        animals_dense_sprite_map.get(.{ .x = 1, .y = 0 }), // Bear
    };
    const enemy_race_colour_lookup: [std.meta.fields(EnemyRace).len]Colour = .{
        .{ .r = 0, .g = 255, .b = 0 }, // Goblin
        .{ .r = 0x79, .g = 0x5c, .b = 0x34 }, // Beast
    };

    var surface_info = getSurface(window);
    var event: c.SDL_Event = undefined;
    var enemies_state: [room_count - 1]EnemyState = undefined;
    inline for (1..room_count) |i| {
        const room = rooms[i];
        const enemy_type = if (i % 2 == 0) .Warrior else .Bear;
        const enemy_race = if (i % 2 == 0) .Goblin else .Beast;
        enemies_state[i - 1] = EnemyState{
            .pos = Pos{
                .x = room.pos.x + random.intRangeLessThan(usize, 0, room.dim.width),
                .y = room.pos.y + random.intRangeLessThan(usize, 0, room.dim.height),
            },
            .type = enemy_type,
            .race = enemy_race,
            .max_health = 10,
            .current_health = 10,
        };
    }
    var game_state = GameState{
        .player_pos = rooms[0].pos,
        .map = map,
        .window_resized = false,
        .running = true,
        .scale = 2,
        .enemies = &enemies_state,
    };

    while (game_state.running) {
        try profiler.capture("MainLoopStart");
        const sprite_dim_pixels = Dim{
            .width = INPUT_SPRITE_DIM_PIXELS.width * game_state.scale,
            .height = INPUT_SPRITE_DIM_PIXELS.height * game_state.scale,
        };

        surface_info.clear();
        game_state.updateVisibility(MAP_MAX_DIMENSION, PLAYER_VIEW_RANGE);

        const clipping_rect = Rect{
            .dim = Dim{ .width = surface_info.width_pixels, .height = surface_info.height_pixels },
            .pos = Pos{ .x = 0, .y = 0 },
        };
        surface_info.drawMap(map, clipping_rect, sprite_dim_pixels, floor_tile_render_data, game_state.player_pos, game_state.scale);
        surface_info.drawEnemies(
            map,
            clipping_rect,
            sprite_dim_pixels,
            &enemy_type_render_info_lookup,
            &enemy_race_colour_lookup,
            game_state.enemies,
            game_state.player_pos,
            game_state.scale,
        );
        surface_info.drawPlayer(clipping_rect, sprite_dim_pixels, rogue_render_data, game_state.scale);

        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                game_state.running = false;
            }
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => game_state.running = false,
                    c.SDLK_UP => game_state.handleMove(Disp{ .dx = 0, .dy = -1 }),
                    c.SDLK_DOWN => game_state.handleMove(Disp{ .dx = 0, .dy = 1 }),
                    c.SDLK_LEFT => game_state.handleMove(Disp{ .dx = -1, .dy = 0 }),
                    c.SDLK_RIGHT => game_state.handleMove(Disp{ .dx = 1, .dy = 0 }),
                    c.SDLK_MINUS => zoomOut(&game_state),
                    c.SDLK_EQUALS => zoomIn(&game_state),
                    else => {},
                }
            }
            if (event.type == c.SDL_WINDOWEVENT) {
                game_state.window_resized = true;
            }
        }
        
        // TODO - enemies move

        if (game_state.window_resized) {
            game_state.window_resized = false;
            surface_info = getSurface(window);
        }

        if (c.SDL_UpdateWindowSurface(window) < 0) {
            @panic("Couldn't update window surface");
        }
        try profiler.capture("MainLoopEnd");

        profiler.report("MainLoopStart", "MainLoopEnd");
    }
}

fn zoomIn(game_state: *GameState) void {
    if (game_state.scale >= MAX_SCALE) return;
    game_state.scale += 1;
}

fn zoomOut(game_state: *GameState) void {
    if (game_state.scale == 1) return;
    game_state.scale -= 1;
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
