const std = @import("std");
const RenderInfo = @import("render_info.zig").RenderInfo;
const Pos = @import("pos.zig").Pos;
const Dim = @import("dim.zig").Dim;
const Rect = @import("rect.zig").Rect;
const Pixel = @import("pixel.zig").Pixel;

pub const PixelFormat = struct {
    r: usize,
    g: usize,
    b: usize,
    a: usize,
};

pub const Colour = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Surface = struct {
    bytes: []u8,
    width_pixels: usize,
    height_pixels: usize,
    pixel_format: PixelFormat,

    const Self = @This();

    pub fn draw(self: Self, input: RenderInfo, pos: Pos, clipping_rect: Rect, scale: usize, override_colour: ?Colour) void {
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
                    if (clipping_rect.contains(write_pos) and !input.stencil_pixel.check(.{ .r = r, .g = g, .b = b, .a = a })) {
                        const write_idx = write_pixel_idx * 4;
                        if (override_colour) |c| {
                            self.bytes[write_idx + self.pixel_format.r] = c.r;
                            self.bytes[write_idx + self.pixel_format.g] = c.g;
                            self.bytes[write_idx + self.pixel_format.b] = c.b;
                            self.bytes[write_idx + self.pixel_format.a] = a;
                        } else {
                            self.bytes[write_idx + self.pixel_format.r] = r;
                            self.bytes[write_idx + self.pixel_format.g] = g;
                            self.bytes[write_idx + self.pixel_format.b] = b;
                            self.bytes[write_idx + self.pixel_format.a] = a;
                        }
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
