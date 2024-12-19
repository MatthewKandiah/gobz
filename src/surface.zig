const RenderInfo = @import("render_info.zig").RenderInfo;

pub const Surface = struct {
    bytes: []u8,
    width_pixels: usize,
    height_pixels: usize,

    const Self = @This();

    pub fn draw(self: Self, render_info: RenderInfo, pos_x: usize, pos_y: usize) void {
        var output_idx: usize = pos_x + pos_y * self.width_pixels;
        var count: usize = 0;
        for (0..render_info.data.len / 4) |i| {
            const r = render_info.data[4 * i];
            const g = render_info.data[4 * i + 1];
            const b = render_info.data[4 * i + 2];
            const a = render_info.data[4 * i + 3];

            self.bytes[4 * output_idx] = b;
            self.bytes[4 * output_idx + 1] = g;
            self.bytes[4 * output_idx + 2] = r;
            self.bytes[4 * output_idx + 3] = a;

            count += 1;
            output_idx += 1;
            if (count >= render_info.width) {
                count = 0;
                output_idx += self.width_pixels - render_info.width;
            }
        }
    }
};

