const std = @import("std");
const RenderInfo = @import("render_info.zig").RenderInfo;
const main = @import("main.zig");
const Pos = main.Pos;
const Dim = main.Dim;
const Rect = main.Rect;

pub const Surface = struct {
    bytes: []u8,
    width_pixels: usize,
    height_pixels: usize,

    const Self = @This();

    // read in from render_info.data RGBA
    // read out to self.bytes BGRA
    // each pixel in input maps to scale-by-scale square in output
    pub fn draw(self: Self, input: RenderInfo, pos: Pos, clipping_rect: Rect, scale: usize) void {
        var read_idx: usize = 0;
        var read_pixel_col: usize = 0;
        var read_pixel_row: usize = 0;
        while (read_idx <= input.data.len - 4) {
            const r = input.data[read_idx];
            const g = input.data[read_idx + 1];
            const b = input.data[read_idx + 2];
            const a = input.data[read_idx + 3];

            for (0..scale) |scale_vertical_count| {
                for (0..scale) |scale_horizontal_count| {
                    const write_pixel_idx = pos.x + scale_horizontal_count + (read_pixel_col * scale) + (pos.y + scale_vertical_count + (read_pixel_row * scale)) * self.width_pixels;
                    const write_pos = Pos{
                        .x = write_pixel_idx % (self.width_pixels),
                        .y = write_pixel_idx / (self.width_pixels),
                    };
                    if (clipping_rect.contains(write_pos)) {
                        const write_idx = write_pixel_idx * 4;
                        self.bytes[write_idx] = b;
                        self.bytes[write_idx + 1] = g;
                        self.bytes[write_idx + 2] = r;
                        self.bytes[write_idx + 3] = a;
                    }
                }
            }

            read_idx += 4;
            read_pixel_col += 1;
            if (read_pixel_col >= input.width) {
                read_pixel_col = 0;
                read_pixel_row += 1;
            }
        }
    }
};
