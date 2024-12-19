const std = @import("std");
const c = @cImport({
    @cInclude("stb_image.h");
});
const RenderInfo = @import("render_info.zig").RenderInfo;

pub const SpriteMap = struct {
    height_sprites: usize,
    width_sprites: usize,
    bytes_per_pixel: usize,
    data: []u8,
    sprite_width_pixels: usize,
    sprite_height_pixels: usize,

    const Self = @This();

    pub fn load(allocator: std.mem.Allocator, path: []const u8, sprite_width_pixels: usize, sprite_height_pixels: usize) !Self {
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
        std.debug.assert(output_idx == input_width * input_height * input_bytes_per_pixel);

        return SpriteMap{
            .height_sprites = sprite_row_count,
            .width_sprites = sprite_column_count,
            .bytes_per_pixel = @intCast(input_bytes_per_pixel),
            .data = output_data,
            .sprite_width_pixels = sprite_width_pixels,
            .sprite_height_pixels = sprite_height_pixels,
        };
    }

    pub fn get(self: Self, x_idx: usize, y_idx: usize) RenderInfo {
        const start_idx = 4 * ((x_idx * self.sprite_width_pixels) + (y_idx * self.sprite_height_pixels * self.width_sprites * self.sprite_width_pixels));
        const byte_count = self.sprite_width_pixels * self.sprite_height_pixels * 4;
        return RenderInfo{
            .width = self.sprite_width_pixels,
            .data = self.data[start_idx .. start_idx + byte_count],
        };
    }
};
