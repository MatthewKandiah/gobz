const Pos = @import("pos.zig").Pos;
const Disp = @import("disp.zig").Disp;
const Map = @import("map.zig").Map;

pub const GameState = struct {
    player_pos: Pos,
    map: Map,

    const Self = @This();

    pub fn handleMove(self: *Self, disp: Disp) void {
        var new_player_x: usize = self.player_pos.x;
        var new_player_y: usize = self.player_pos.y;
        const shifted_x = @as(i32, @intCast(self.player_pos.x)) + disp.dx;
        const shifted_y = @as(i32, @intCast(self.player_pos.y)) + disp.dy;
        if (shifted_x >= 0 and shifted_x < self.map.dim_tiles.width) {
            new_player_x = @intCast(shifted_x);
        }
        if (shifted_y >= 0 and shifted_y < self.map.dim_tiles.height) {
            new_player_y = @intCast(shifted_y);
        }
        if (self.map.get(Pos{ .x = new_player_x, .y = new_player_y }) != .Wall) {
            self.*.player_pos.x = new_player_x;
            self.*.player_pos.y = new_player_y;
        }
    }

    pub fn updateVisibility(self: *Self, view_range: f32) void {
        for (0..self.map.dim_tiles.height) |j| {
            for (0..self.map.dim_tiles.width) |i| {
                const p = Pos{ .x = i, .y = j };
                if (p.dist(self.player_pos) < view_range) {
                    self.map.setVisibility(p, .Visible);
                } else if (self.map.getVisibility(p) == .Visible) {
                    self.map.setVisibility(p, .KnownNotVisible);
                }
            }
        }
    }
};
