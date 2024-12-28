const Dim = @import("dim.zig").Dim;
const Pos = @import("pos.zig").Pos;

pub const Rect = struct {
    dim: Dim,
    pos: Pos,

    const Self = @This();

    pub fn contains(self: Self, pos: Pos) bool {
        return (pos.x >= self.pos.x and pos.x < self.pos.x + self.dim.width) and (pos.y >= self.pos.y and pos.y < self.pos.y + self.dim.height);
    }
};
