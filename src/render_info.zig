const Pixel = @import("pixel.zig").Pixel;

pub const FullRenderInfo = struct {
    width: usize,
    data: []u8,
    stencil_pixel: Pixel,
};

pub const DenseRenderInfo = struct {
    width: usize,
    data: []bool,
};
