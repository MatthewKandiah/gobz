const MapValue = @import("map_value.zig").MapValue;
const Dim = @import("dim.zig").Dim;
const Pos = @import("pos.zig").Pos;
const VisibilityValue = @import("visibility_value.zig").VisibilityValue;

pub const Map = struct {
    data: []const MapValue,
    visibility: []VisibilityValue,
    dim_tiles: Dim,

    const Self = @This();

    fn index(self: Self, pos: Pos) usize {
        return pos.x + pos.y * self.dim_tiles.width;
    }

    fn isOutsideMap(self: Self, pos: Pos) bool {
        return pos.x >= self.dim_tiles.width or pos.y >= self.dim_tiles.height;
    }

    pub fn get(self: Self, pos: Pos) ?MapValue {
        if (self.isOutsideMap(pos)) {
            return null;
        }
        const idx = self.index(pos);
        return self.data[idx];
    }

    pub fn set(self: *Self, pos: Pos, value: MapValue) void {
        if (self.isOutsideMap(pos)) {
            return;
        }
        const idx = self.index(pos);
        self.data[idx] = value;
    }

    pub fn getVisibility(self: Self, pos: Pos) VisibilityValue {
        if (self.isOutsideMap(pos)) {
            @panic("bad getVisibility");
        }
        const idx = self.index(pos);
        return self.visibility[idx];
    }

    pub fn setVisibility(self: *Self, pos: Pos, value: VisibilityValue) void {
        if (self.isOutsideMap(pos)) {
            return;
        }
        const idx = self.index(pos);
        self.visibility[idx] = value;
    }
};
