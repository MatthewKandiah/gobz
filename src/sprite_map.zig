const std = @import("std");
const c = @cImport({
    @cInclude("stb_image.h");
});
const RenderInfo = @import("render_info.zig").RenderInfo;
const Dim = @import("dim.zig").Dim;
const Pixel = @import("pixel.zig").Pixel;

pub const SpriteMap = struct {
    data: []u8,
    bytes_per_pixel: usize,
    dim_sprites: Dim,
    sprite_dim_pixels: Dim,
    background_pixel: Pixel,

    const Self = @This();

    pub fn load(allocator: std.mem.Allocator, path: []const u8, sprite_width_pixels: usize, sprite_height_pixels: usize, background_pixel: Pixel) !Self {
        var input_width: c_int = undefined;
        var input_height: c_int = undefined;
        var input_bytes_per_pixel: c_int = undefined;
        var input_data: [*]u8 = undefined;
        input_data = c.stbi_load(@ptrCast(path), &input_width, &input_height, &input_bytes_per_pixel, 0);
        defer c.stbi_image_free(input_data);

        std.debug.assert(input_bytes_per_pixel == 4);
        const height_pixels: usize = @intCast(input_height);
        const width_pixels: usize = @intCast(input_width);
        const sprite_column_count = width_pixels / sprite_width_pixels;
        const sprite_row_count = height_pixels / sprite_height_pixels;
        const output_data = try allocator.alloc(u8, @intCast(input_width * input_height * 4));
        var output_idx: usize = 0;
        for (0..sprite_row_count) |sprite_row_idx| {
            for (0..sprite_column_count) |sprite_col_idx| {
                const sprite_data_top_left_idx = ((sprite_row_idx * sprite_height_pixels * width_pixels) + (sprite_col_idx * sprite_width_pixels)) * 4;
                for (0..sprite_height_pixels) |j| {
                    for (0..sprite_width_pixels * 4) |i| {
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
            .sprite_dim_pixels = Dim{ .height = sprite_height_pixels, .width = sprite_width_pixels },
            .background_pixel = background_pixel,
        };
    }

    pub fn get(self: Self, x_idx: usize, y_idx: usize) RenderInfo {
        const start_idx = 4 * ((x_idx * self.sprite_dim_pixels.width) + (y_idx * self.sprite_dim_pixels.height * self.dim_sprites.width * self.sprite_dim_pixels.width));
        const byte_count = self.sprite_dim_pixels.width * self.sprite_dim_pixels.height * 4;
        return RenderInfo{
            .width = self.sprite_dim_pixels.width,
            .data = self.data[start_idx .. start_idx + byte_count],
            .stencil_pixel = self.background_pixel,
        };
    }
};
