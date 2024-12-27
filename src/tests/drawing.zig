const std = @import("std");
const c = @cImport({
    @cInclude("stb_image_write.h");
});
const SpriteMap = @import("../sprite_map.zig").SpriteMap;
const Surface = @import("../surface.zig").Surface;
const Dim = @import("../main.zig").Dim;
const Pos = @import("../main.zig").Pos;
const Rect = @import("../main.zig").Rect;

// TODO - refactor out a snapshot testing util
// TODO - use a build option to set if we're checking values or overwriting them, currently we just overwrite them everytime
// TODO - colours are wonky because my SDL surface pixel format is different from the stb_image_write pixel format, test still functions to catch changes in logic, but a little sad

test "should render a 32x32 pixel sprite from spritesheet image" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 32, 32);
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    for (&bytes) |*b| {
        b.* = 255;
    }
    const surface = Surface{
        .bytes = &bytes,
        .width_pixels = 64,
        .height_pixels = 64,
    };

    surface.draw(
        render_data,
        Pos{ .x = 16, .y = 16 },
        Rect{
            .dim = surface_dim,
            .pos = Pos{ .x = 0, .y = 0 },
        },
        1,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_32x32.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should reneder a 64x64 pixel sprite from spritesheet image" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 64, 64);
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    for (&bytes) |*b| {
        b.* = 255;
    }
    const surface = Surface{
        .bytes = &bytes,
        .width_pixels = 64,
        .height_pixels = 64,
    };

    surface.draw(
        render_data,
        Pos{ .x = 0, .y = 0 },
        Rect{
            .dim = surface_dim,
            .pos = Pos{ .x = 0, .y = 0 },
        },
        1,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_64x64.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should only render pixels inside clipping rect" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 64, 64);
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    for (&bytes) |*b| {
        b.* = 255;
    }
    const surface = Surface{
        .bytes = &bytes,
        .width_pixels = 64,
        .height_pixels = 64,
    };

    surface.draw(
        render_data,
        Pos{ .x = 0, .y = 0 },
        Rect{
            .dim = Dim{ .width = 32, .height = 32 },
            .pos = Pos{ .x = 16, .y = 16 },
        },
        1,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_64x64_clipped.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should render a 32x32 pixel scaled up to 64x64" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sprite_sheet = try SpriteMap.load(allocator, "sprites/32rogues/rogues.png", 32, 32);
    const render_data = sprite_sheet.get(0, 0);

    const surface_dim = Dim{ .width = 64, .height = 64 };
    var bytes: [surface_dim.width * surface_dim.height * 4]u8 = undefined;
    for (&bytes) |*b| {
        b.* = 255;
    }
    const surface = Surface{
        .bytes = &bytes,
        .width_pixels = 64,
        .height_pixels = 64,
    };

    surface.draw(
        render_data,
        Pos{ .x = 0, .y = 0 },
        Rect{
            .dim = surface_dim,
            .pos = Pos{ .x = 0, .y = 0 },
        },
        2,
    );

    const write_res = c.stbi_write_png("snapshot/drawing_32x32_scale_2.png", surface_dim.width, surface_dim.height, 4, @ptrCast(surface.bytes), surface_dim.width * 4);
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}
