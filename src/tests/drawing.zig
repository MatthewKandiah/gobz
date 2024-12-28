const std = @import("std");
const c = @cImport({
    @cInclude("stb_image_write.h");
});
const SpriteMap = @import("../sprite_map.zig").SpriteMap;
const Surface = @import("../surface.zig").Surface;
const Dim = @import("../dim.zig").Dim;
const Pos = @import("../pos.zig").Pos;
const Rect = @import("../rect.zig").Rect;

// TODO - refactor out a snapshot testing util
// TODO - use a build option to set if we're checking values or overwriting them, currently we just overwrite them everytime

fn makeTestSurface(bytes: []u8, dim: Dim) Surface {
    for (bytes) |*b| {
        b.* = 255;
    }
    return Surface{
        .bytes = bytes,
        .width_pixels = dim.width,
        .height_pixels = dim.height,
        .pixel_format = .{ .r = 0, .g = 1, .b = 2, .a = 3 },
    };
}

test "should render a 32x32 pixel sprite from spritesheet image" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 32, 32, .{ .a = 0 });
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, surface_dim);

    surface.draw(
        render_data,
        Pos{ .x = 16, .y = 16 },
        Rect{
            .dim = surface_dim,
            .pos = Pos{ .x = 0, .y = 0 },
        },
        1,
        null,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_32x32.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should reneder a 64x64 pixel sprite from spritesheet image" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 64, 64, .{ .a = 0 });
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, surface_dim);

    surface.draw(
        render_data,
        Pos{ .x = 0, .y = 0 },
        Rect{
            .dim = surface_dim,
            .pos = Pos{ .x = 0, .y = 0 },
        },
        1,
        null,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_64x64.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should only render pixels inside clipping rect" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 64, 64, .{ .a = 0 });
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, surface_dim);

    surface.draw(
        render_data,
        Pos{ .x = 0, .y = 0 },
        Rect{
            .dim = Dim{ .width = 32, .height = 32 },
            .pos = Pos{ .x = 16, .y = 16 },
        },
        1,
        null,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_64x64_clipped.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should render a 32x32 pixel scaled up to 64x64" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 32, 32, .{ .a = 0 });
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, surface_dim);

    surface.draw(
        render_data,
        Pos{ .x = 0, .y = 0 },
        Rect{
            .dim = surface_dim,
            .pos = Pos{ .x = 0, .y = 0 },
        },
        2,
        null,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_32x32_scale_2.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should render a 32x32 pixel sprite with override colour" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 32, 32, .{ .a = 0 });
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, surface_dim);

    surface.draw(
        render_data,
        Pos{ .x = 0, .y = 0 },
        Rect{
            .dim = surface_dim,
            .pos = Pos{ .x = 0, .y = 0 },
        },
        2,
        .{ .r = 255, .g = 0, .b = 0 },
    );

    const write_res = c.stbi_write_png("snapshot/drawing_32x32_scale_2_override_red.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}
