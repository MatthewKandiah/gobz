const MapValue = @import("map_value.zig").MapValue;
const Dim = @import("dim.zig").Dim;

pub const Map = struct {
    data: []const MapValue,
    dim_tiles: Dim,

    const Self = @This();

    pub fn get(self: Self, x: usize, y: usize) ?MapValue {
        if (x >= self.dim_tiles.width or y >= self.dim_tiles.height) {
            return null;
        }
        return self.data[y * self.dim_tiles.width + x];
    }
};
