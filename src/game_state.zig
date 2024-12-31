const std = @import("std");
const Pos = @import("pos.zig").Pos;
const Disp = @import("disp.zig").Disp;
const Map = @import("map.zig").Map;

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

    // TODO - WIP this sort of almost works
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

    fn drawLine(start: Pos, end: Pos, pos_buffer: []Pos) []Pos {
        const dx: f64 = @as(f64, @floatFromInt(end.x)) - @as(f64, @floatFromInt(start.x));
        const dy: f64 = @as(f64, @floatFromInt(end.y)) - @as(f64, @floatFromInt(start.y));
        if (dx == 0 and dy == 0) {
            // special handling or we'll get a divide by zero when calculating gradients
            pos_buffer[0] = start;
            return pos_buffer[0..1];
        }
        if (@abs(dx) >= @abs(dy)) {
            // we are travelling at least as far horizontally as vertically, so we'll have one value in each column, potentially multiple values in each row
            std.debug.assert(@as(f64, @floatFromInt(pos_buffer.len)) >= dx);
            const gradient = dy / dx;
            std.debug.assert(@abs(gradient) <= 1);
            var insert_idx: usize = 0;
            var current_y = @as(f64, @floatFromInt(start.y));
            while (@as(f64, @floatFromInt(insert_idx)) < dx) {
                const current_pos = if (dx > 0) Pos{ .x = start.x + insert_idx, .y = @intFromFloat(@trunc(current_y)) } else Pos{ .x = start.x - insert_idx, .y = @intFromFloat(@trunc(current_y)) };
                pos_buffer[insert_idx] = current_pos;
                insert_idx += 1;
                current_y += gradient;
            }
            return pos_buffer[0..insert_idx];
        } else {
            // we are travelling further vertically than horizontally, we'll have one value in each row, potentially multiple values in each column
            std.debug.assert(@as(f64, @floatFromInt(pos_buffer.len)) >= dy);
            const gradient = dx / dy;
            std.debug.assert(@abs(gradient) <= 1);
            var insert_idx: usize = 0;
            var current_x = @as(f64, @floatFromInt(start.x));
            while (@as(f64, @floatFromInt(insert_idx)) < dy) {
                const current_pos = if (dy > 0) Pos{ .x = @intFromFloat(@trunc(current_x)), .y = start.y + insert_idx } else Pos{ .x = @intFromFloat(@trunc(current_x)), .y = start.y + insert_idx };
                pos_buffer[insert_idx] = current_pos;
                insert_idx += 1;
                current_x += gradient;
            }
            std.debug.print("start: x={}, y={}; end: x={}, y={}; output={any}\n", .{ start.x, start.y, end.x, end.y, pos_buffer[0..insert_idx] });
            return pos_buffer[0..insert_idx];
        }
    }
};
