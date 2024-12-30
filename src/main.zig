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
const VisibilityValue = @import("visibility_value.zig").VisibilityValue;
const Profiler = @import("profiler.zig").Profiler;

const DEFAULT_WIDTH = 800;
const DEFAULT_HEIGHT = 800;
const INPUT_SPRITE_DIM_PIXELS = .{ .width = 32, .height = 32 };
const MAX_SCALE = 5;
const PLAYER_VIEW_RANGE = 8;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var profiler = Profiler.init(allocator);

    var scale: usize = 2;

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
    const tiles_sprite_map = try SpriteMap.load(allocator, "./sprites/32rogues/tiles.png", INPUT_SPRITE_DIM_PIXELS, Pixel{ .a = 0 });

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

    const rogue_render_data = rogues_dense_sprite_map.get(0, 0);
    const floor_tile_render_data = tiles_sprite_map.get(0, 1);

    var surface_info = getSurface(window);
    var running = true;
    var event: c.SDL_Event = undefined;
    var game_state = GameState{
        .player_pos = rooms[0].pos,
        .map = map,
        .window_resized = false,
    };

    while (running) {
        try profiler.capture("MainLoopStart");
        const sprite_dim_pixels = Dim{
            .width = INPUT_SPRITE_DIM_PIXELS.width * scale,
            .height = INPUT_SPRITE_DIM_PIXELS.height * scale,
        };

        surface_info.clear();
        game_state.updateVisibility(PLAYER_VIEW_RANGE);

        const clipping_rect = Rect{
            .dim = Dim{ .width = surface_info.width_pixels, .height = surface_info.height_pixels },
            .pos = Pos{ .x = 0, .y = 0 },
        };
        surface_info.drawMap(map, clipping_rect, sprite_dim_pixels, floor_tile_render_data, game_state.player_pos, scale);
        surface_info.drawPlayer(clipping_rect, sprite_dim_pixels, rogue_render_data, scale);

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
                game_state.window_resized = true;
            }
        }

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
