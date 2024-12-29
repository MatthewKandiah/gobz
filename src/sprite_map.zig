const std = @import("std");
const c = @cImport({
    @cInclude("stb_image.h");
});
const RenderInfo = @import("render_info.zig");
const FullRenderInfo = RenderInfo.FullRenderInfo;
const DenseRenderInfo = RenderInfo.DenseRenderInfo;
const Dim = @import("dim.zig").Dim;
const Pixel = @import("pixel.zig").Pixel;

pub const SpriteMap = struct {
    data: []u8,
    bytes_per_pixel: usize,
    dim_sprites: Dim,
    sprite_dim_pixels: Dim,
    background_pixel: Pixel,

    const Self = @This();

    pub fn load(allocator: std.mem.Allocator, path: []const u8, sprite_dim_pixels: Dim, background_pixel: Pixel) !Self {
        var input_width: c_int = undefined;
        var input_height: c_int = undefined;
        var input_bytes_per_pixel: c_int = undefined;
        var input_data: [*]u8 = undefined;
        input_data = c.stbi_load(@ptrCast(path), &input_width, &input_height, &input_bytes_per_pixel, 0);
        defer c.stbi_image_free(input_data);

        std.debug.assert(input_bytes_per_pixel == 4);
        const height_pixels: usize = @intCast(input_height);
        const width_pixels: usize = @intCast(input_width);
        const sprite_column_count = width_pixels / sprite_dim_pixels.width;
        const sprite_row_count = height_pixels / sprite_dim_pixels.height;
        const output_data = try allocator.alloc(u8, @intCast(input_width * input_height * 4));
        var output_idx: usize = 0;
        for (0..sprite_row_count) |sprite_row_idx| {
            for (0..sprite_column_count) |sprite_col_idx| {
                const sprite_data_top_left_idx = ((sprite_row_idx * sprite_dim_pixels.height * width_pixels) + (sprite_col_idx * sprite_dim_pixels.width)) * 4;
                for (0..sprite_dim_pixels.height) |j| {
                    for (0..sprite_dim_pixels.width * 4) |i| {
                        const input_data_idx = sprite_data_top_left_idx + (j * width_pixels * 4) + i;
                        output_data[output_idx] = input_data[input_data_idx];
                        output_idx += 1;
                    }
                }
            }
        }

        return SpriteMap{
            .dim_sprites = Dim{ .height = sprite_row_count, .width = sprite_column_count },
            .bytes_per_pixel = @intCast(input_bytes_per_pixel),
            .data = output_data,
            .sprite_dim_pixels = Dim{ .height = sprite_dim_pixels.height, .width = sprite_dim_pixels.width },
            .background_pixel = background_pixel,
        };
    }

    // TODO - Pos refactor
    pub fn get(self: Self, x_idx: usize, y_idx: usize) FullRenderInfo {
        const start_idx = 4 * ((x_idx * self.sprite_dim_pixels.width) + (y_idx * self.sprite_dim_pixels.height * self.dim_sprites.width * self.sprite_dim_pixels.width));
        const byte_count = self.sprite_dim_pixels.width * self.sprite_dim_pixels.height * 4;
        return FullRenderInfo{
            .width = self.sprite_dim_pixels.width,
            .data = self.data[start_idx .. start_idx + byte_count],
            .stencil_pixel = self.background_pixel,
        };
    }

    pub fn toDense(self: Self, allocator: std.mem.Allocator) !DenseSpriteMap {
        const buf_size = self.data.len / 4;
        var data_buf = try allocator.alloc(bool, buf_size);

        for (0..buf_size) |i| {
            const input_pixel = Pixel{
                .r = self.data[4 * i + 0],
                .g = self.data[4 * i + 1],
                .b = self.data[4 * i + 2],
                .a = self.data[4 * i + 3],
            };
            const is_background = self.background_pixel.check(input_pixel);
            data_buf[i] = !is_background;
        }

        return DenseSpriteMap{
            .data = data_buf,
            .dim_sprites = self.dim_sprites,
            .sprite_dim_pixels = self.sprite_dim_pixels,
        };
    }
};

pub const DenseSpriteMap = struct {
    data: []bool,
    dim_sprites: Dim,
    sprite_dim_pixels: Dim,

    const Self = @This();

    // TODO - Pos refactor
    pub fn get(self: Self, x_idx: usize, y_idx: usize) DenseRenderInfo {
        const start_idx = (x_idx * self.sprite_dim_pixels.width) + (y_idx * self.sprite_dim_pixels.height * self.dim_sprites.width * self.sprite_dim_pixels.width);
        const bool_count = self.sprite_dim_pixels.width * self.sprite_dim_pixels.height;
        return DenseRenderInfo{
            .width = self.sprite_dim_pixels.width,
            .data = self.data[start_idx .. start_idx + bool_count],
        };
    }
};
