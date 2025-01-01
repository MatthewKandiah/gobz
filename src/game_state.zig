const std = @import("std");
const Pos = @import("pos.zig").Pos;
const Disp = @import("disp.zig").Disp;
const Map = @import("map.zig").Map;
const drawLine = @import("draw_line.zig").drawLine;

pub const GameState = struct {
    player_pos: Pos,
    map: Map,
    window_resized: bool,
    running: bool,
    scale: usize,

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

    pub fn updateVisibility(self: *Self, comptime max_map_dimension: usize, view_range: f32) void {
        var draw_line_buffer: [max_map_dimension]Pos = undefined;
        for (0..self.map.dim_tiles.height) |j| {
            for (0..self.map.dim_tiles.width) |i| {
                const p = Pos{ .x = i, .y = j };
                const current_visibility = self.map.getVisibility(p);
                var blocker_found = false;
                if (p.dist(self.player_pos) < view_range) {
                    const tile_positions_from_player_to_p = drawLine(self.player_pos, p, &draw_line_buffer);
                    for (tile_positions_from_player_to_p) |tp| {
                        const t = self.map.get(tp);
                        if (t == .Wall) {
                            blocker_found = true;
                            break;
                        }
                    }
                    if (blocker_found) {
                        if (current_visibility != .Unknown) {
                            self.map.setVisibility(p, .KnownNotVisible);
                        }
                    } else {
                        self.map.setVisibility(p, .Visible);
                    }
                } else if (current_visibility == .Visible) {
                    self.map.setVisibility(p, .KnownNotVisible);
                }
            }
        }
    }

};
