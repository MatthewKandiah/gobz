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

const RED = Colour{ .r = 255, .g = 0, .b = 0 };

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
        options.sprite_dim_pixels,
        options.background_pixel,
    );
    const render_data = sprite_sheet.get(.{ .x = 0, .y = 0 });
    var bytes: [options.surface_dim.height * options.surface_dim.width * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, options.surface_dim);

    surface.drawFull(
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

const DenseSnapshotOptions = struct {
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
    draw_colour: Colour = RED,
    snapshot_path: []const u8,
};

fn doDenseSnapshotTest(comptime options: DenseSnapshotOptions) !void {
    const sprite_sheet = try SpriteMap.load(
        allocator,
        options.sprite_sheet_path,
        options.sprite_dim_pixels,
        options.background_pixel,
    );
    const dense_sprite_sheet = try sprite_sheet.toDense(allocator);
    const render_data = dense_sprite_sheet.get(.{ .x = 0, .y = 0 });
    var bytes: [options.surface_dim.height * options.surface_dim.width * 4]u8 = undefined;
    const surface = makeTestSurface(&bytes, options.surface_dim);

    surface.drawDense(
        render_data,
        options.draw_pos,
        options.draw_clipping_rect,
        options.draw_scale,
        options.draw_colour,
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
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_32x32.png",
        .draw_pos = .{ .x = 16, .y = 16 },
    });

    try doDenseSnapshotTest(DenseSnapshotOptions{
        .snapshot_path = "snapshot/dense_drawing_32x32.png",
        .draw_pos = .{ .x = 16, .y = 16 },
    });
}

test "should reneder a 64x64 pixel sprite from spritesheet image" {
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_64x64.png",
        .sprite_dim_pixels = .{ .height = 64, .width = 64 },
    });

    try doDenseSnapshotTest(DenseSnapshotOptions{
        .snapshot_path = "snapshot/dense_drawing_64x64.png",
        .sprite_dim_pixels = .{ .height = 64, .width = 64 },
    });
}

test "should only render pixels inside clipping rect" {
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_64x64_clipped.png",
        .sprite_dim_pixels = .{ .width = 64, .height = 64 },
        .draw_clipping_rect = .{
            .pos = .{ .x = 16, .y = 16 },
            .dim = .{ .width = 32, .height = 32 },
        },
    });

    try doDenseSnapshotTest(DenseSnapshotOptions{
        .snapshot_path = "snapshot/dense_drawing_64x64_clipped.png",
        .sprite_dim_pixels = .{ .width = 64, .height = 64 },
        .draw_clipping_rect = .{
            .pos = .{ .x = 16, .y = 16 },
            .dim = .{ .width = 32, .height = 32 },
        },
    });
}

test "should render a 32x32 pixel scaled up to 64x64" {
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_32x32_scale_2.png",
        .draw_scale = 2,
    });

    try doDenseSnapshotTest(DenseSnapshotOptions{
        .snapshot_path = "snapshot/dense_drawing_32x32_scale_2.png",
        .draw_scale = 2,
    });
}

test "should render a 32x32 pixel sprite with override colour" {
    try doSnapshotTest(SnapshotOptions{
        .snapshot_path = "snapshot/drawing_32x32_scale_2_override_red.png",
        .draw_scale = 2,
        .draw_override_colour = RED,
    });
}
