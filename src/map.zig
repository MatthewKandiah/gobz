const MapValue = @import("map_value.zig").MapValue;
const Dim = @import("dim.zig").Dim;
const Pos = @import("pos.zig").Pos;

pub const Map = struct {
    data: []const MapValue,
    dim_tiles: Dim,

    const Self = @This();

    fn index(self: Self, pos: Pos) usize {
        return pos.x + pos.y * self.dim_tiles.width;
    }

    pub fn get(self: Self, pos: Pos) ?MapValue {
        if (pos.x >= self.dim_tiles.width or pos.y >= self.dim_tiles.height) {
            return null;
        }
        const idx = self.index(pos);
        return self.data[idx];
    }

    pub fn set(self: *Self, pos: Pos, value: MapValue) void {
        if (pos.x >= self.dim_tiles.width or pos.y >= self.dim_tiles.height) {
            return;
        }
        const idx = self.index(pos);
        self.data[idx] = value;

    }
};
