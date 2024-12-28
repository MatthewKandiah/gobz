const MapValue = @import("map_value.zig").MapValue;

pub const Map = struct {
    data: []const MapValue,
    height: usize,
    width: usize,

    const Self = @This();

    pub fn get(self: Self, x: usize, y: usize) ?MapValue {
        if (x >= self.width or y >= self.height) {
            return null;
        }
        return self.data[y * self.width + x];
    }
};
