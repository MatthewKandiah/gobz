const Pixel = @import("pixel.zig").Pixel;

pub const RenderInfo = struct {
    width: usize,
    data: []u8,
    stencil_pixel: Pixel,
};
