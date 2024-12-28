const std = @import("std");
const c = @cImport({
    @cInclude("stb_image_write.h");
});
const SpriteMap = @import("../sprite_map.zig").SpriteMap;
const Surface = @import("../surface.zig").Surface;
const Dim = @import("../dim.zig").Dim;
const Pos = @import("../pos.zig").Pos;
const Rect = @import("../rect.zig").Rect;
const Pixel = @import("../pixel.zig").Pixel;
const Colour = @import("../colour.zig").Colour;

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

const SnapshotOptions = struct {
    sprite_sheet_path: []const u8 = "sprites/32rogues/rogues.png",
    sprite_dim_pixels: Dim = .{ .width = 32, .height = 32 },
    background_pixel: Pixel = .{ .a = 0 },
    surface_dim: Dim = .{ .width = 64, .height = 64 },
    draw_pos: Pos = .{ .x = 0, .y = 0 },
    draw_clipping_rect: Rect = .{
        .pos = .{ .x = 0, .y = 0 },
        .dim = .{ .width = 64, .height = 64 },
    },
    draw_scale: usize = 1,
    draw_override_colour: ?Colour = null,
    snapshot_path: []const u8,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn doSnapshotTest(comptime options: SnapshotOptions) !void {
    const sprite_sheet = try SpriteMap.load(
        allocator,
        options.sprite_sheet_path,
        options.sprite_dim_pixels.width,
        options.sprite_dim_pixels.height,
        options.background_pixel,
    );
    const render_data = sprite_sheet.get(0, 0);
    var bytes: [options.surface_dim.height * options.surface_dim.width * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, options.surface_dim);

    surface.draw(
        render_data,
        options.draw_pos,
        options.draw_clipping_rect,
        options.draw_scale,
        options.draw_override_colour,
    );

    const write_res = c.stbi_write_png(
        @ptrCast(options.snapshot_path),
        options.surface_dim.width,
        options.surface_dim.height,
        4,
        @ptrCast(surface.bytes),
        options.surface_dim.width * 4,
    );
    if (write_res == 0) {
        @panic("Failed to write snapshot image");
    }
}

test "should render a 32x32 pixel sprite from spritesheet image" {
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_32x32.png",
        .draw_pos = .{ .x = 16, .y = 16 },
    });
}

test "should reneder a 64x64 pixel sprite from spritesheet image" {
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_64x64.png",
        .sprite_dim_pixels = .{ .height = 64, .width = 64 },
    });
}

test "should only render pixels inside clipping rect" {
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
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_64x64_clipped.png",
        .sprite_dim_pixels = .{ .width = 64, .height = 64 },
        .draw_clipping_rect = .{
            .pos = .{ .x = 16, .y = 16 },
            .dim = .{ .width = 32, .height = 32 },
        },
    });
}

test "should render a 32x32 pixel scaled up to 64x64" {
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
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_32x32_scale_2.png",
        .draw_scale = 2,
    });
}

test "should render a 32x32 pixel sprite with override colour" {
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
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_32x32_scale_2_override_red.png",
        .draw_scale = 2,
        .draw_override_colour = .{ .r = 255, .g = 0, .b = 0 },
    });
}
