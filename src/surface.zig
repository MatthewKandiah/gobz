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

    pub fn draw(self: Self, render_info: RenderInfo, pos: Pos, clipping_rect: Rect) void {
        var output_idx: usize = pos.x + pos.y * self.width_pixels;
        var count: usize = 0;
        var current_pos = Pos{ .x = pos.x, .y = pos.y };
        for (0..render_info.data.len / 4) |i| {
            if (clipping_rect.contains(current_pos)) {
                const r = render_info.data[4 * i];
                const g = render_info.data[4 * i + 1];
                const b = render_info.data[4 * i + 2];
                const a = render_info.data[4 * i + 3];

                self.bytes[4 * output_idx] = b;
                self.bytes[4 * output_idx + 1] = g;
                self.bytes[4 * output_idx + 2] = r;
                self.bytes[4 * output_idx + 3] = a;
            }
            count += 1;
            output_idx += 1;
            current_pos.x += 1;
            if (count >= render_info.width) {
                count = 0;
                output_idx += self.width_pixels - render_info.width;
                current_pos.x = pos.x;
                current_pos.y += 1;
            }
        }
    }
};
