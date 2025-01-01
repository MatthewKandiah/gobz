const std = @import("std");
const Pos = @import("pos.zig").Pos;

pub fn drawLine(start: Pos, end: Pos, pos_buffer: []Pos) []Pos {
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
        const going_right = dx > 0;
        while (@as(f64, @floatFromInt(insert_idx)) <= @abs(dx)) {
            const current_pos = if (going_right) Pos{ .x = start.x + insert_idx, .y = @intFromFloat(@round(current_y)) } else Pos{ .x = start.x - insert_idx, .y = @intFromFloat(@round(current_y)) };
            pos_buffer[insert_idx] = current_pos;
            insert_idx += 1;
            current_y += if (going_right) gradient else -gradient;
        }
        return pos_buffer[0..insert_idx];
    } else {
        // we are travelling further vertically than horizontally, we'll have one value in each row, potentially multiple values in each column
        std.debug.assert(@as(f64, @floatFromInt(pos_buffer.len)) >= dy);
        const gradient = dx / dy;
        std.debug.assert(@abs(gradient) <= 1);
        var insert_idx: usize = 0;
        var current_x = @as(f64, @floatFromInt(start.x));
        const going_up = dy > 0;
        while (@as(f64, @floatFromInt(insert_idx)) <= @abs(dy)) {
            const current_pos = if (going_up) Pos{ .x = @intFromFloat(@round(current_x)), .y = start.y + insert_idx } else Pos{ .x = @intFromFloat(@round(current_x)), .y = start.y - insert_idx };
            pos_buffer[insert_idx] = current_pos;
            insert_idx += 1;
            current_x += if (going_up) gradient else -gradient;
        }
        return pos_buffer[0..insert_idx];
    }
}

var test_draw_line_buf: [10]Pos = undefined;

test "should draw a line with start and end at same point" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 5, .y = 7 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{Pos{ .x = 5, .y = 7 }},
        result,
    );
}

test "should draw vertical line up" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 5, .y = 9 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 5, .y = 8 }, Pos{ .x = 5, .y = 9 } },
        result,
    );
}

test "should draw vertical line down" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 5, .y = 5 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 5, .y = 6 }, Pos{ .x = 5, .y = 5 } },
        result,
    );
}

test "should draw horizontal line right" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 7, .y = 7 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 6, .y = 7 }, Pos{ .x = 7, .y = 7 } },
        result,
    );
}

test "should draw horizontal line left" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 3, .y = 7 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 4, .y = 7 }, Pos{ .x = 3, .y = 7 } },
        result,
    );
}

test "should draw line up-right" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 7, .y = 9 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 6, .y = 8 }, Pos{ .x = 7, .y = 9 } },
        result,
    );
}

test "should draw line down-right" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 7, .y = 5 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 6, .y = 6 }, Pos{ .x = 7, .y = 5 } },
        result,
    );
}

test "should draw line down-left" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 3, .y = 5 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 4, .y = 6 }, Pos{ .x = 3, .y = 5 } },
        result,
    );
}

test "should draw line up-left" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 3, .y = 9 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{ Pos{ .x = 5, .y = 7 }, Pos{ .x = 4, .y = 8 }, Pos{ .x = 3, .y = 9 } },
        result,
    );
}

test "should draw steep line up-right" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 7, .y = 13 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 5, .y = 7 },
            Pos{ .x = 5, .y = 8 },
            Pos{ .x = 6, .y = 9 },
            Pos{ .x = 6, .y = 10 },
            Pos{ .x = 6, .y = 11 },
            Pos{ .x = 7, .y = 12 },
            Pos{ .x = 7, .y = 13 },
        },
        result,
    );
}

test "should draw shallow line up-right" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 11, .y = 9 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 5, .y = 7 },
            Pos{ .x = 6, .y = 7 },
            Pos{ .x = 7, .y = 8 },
            Pos{ .x = 8, .y = 8 },
            Pos{ .x = 9, .y = 8 },
            Pos{ .x = 10, .y = 9 },
            Pos{ .x = 11, .y = 9 },
        },
        result,
    );
}

test "should draw steep line down-right" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 7, .y = 1 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 5, .y = 7 },
            Pos{ .x = 5, .y = 6 },
            Pos{ .x = 6, .y = 5 },
            Pos{ .x = 6, .y = 4 },
            Pos{ .x = 6, .y = 3 },
            Pos{ .x = 7, .y = 2 },
            Pos{ .x = 7, .y = 1 },
        },
        result,
    );
}

test "should draw shallow line down-right" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 11, .y = 5 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 5, .y = 7 },
            Pos{ .x = 6, .y = 7 },
            Pos{ .x = 7, .y = 6 },
            Pos{ .x = 8, .y = 6 },
            Pos{ .x = 9, .y = 6 },
            Pos{ .x = 10, .y = 5 },
            Pos{ .x = 11, .y = 5 },
        },
        result,
    );
}

test "should draw steep line down-left" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 3, .y = 1 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 5, .y = 7 },
            Pos{ .x = 5, .y = 6 },
            Pos{ .x = 4, .y = 5 },
            Pos{ .x = 4, .y = 4 },
            Pos{ .x = 4, .y = 3 },
            Pos{ .x = 3, .y = 2 },
            Pos{ .x = 3, .y = 1 },
        },
        result,
    );
}

test "should draw shallow line down-left" {
    const start = Pos{ .x = 11, .y = 7 };
    const end = Pos{ .x = 5, .y = 5 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 11, .y = 7 },
            Pos{ .x = 10, .y = 7 },
            Pos{ .x = 9, .y = 6 },
            Pos{ .x = 8, .y = 6 },
            Pos{ .x = 7, .y = 6 },
            Pos{ .x = 6, .y = 5 },
            Pos{ .x = 5, .y = 5 },
        },
        result,
    );
}

test "should draw steep line up-left" {
    const start = Pos{ .x = 5, .y = 7 };
    const end = Pos{ .x = 3, .y = 13 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 5, .y = 7 },
            Pos{ .x = 5, .y = 8 },
            Pos{ .x = 4, .y = 9 },
            Pos{ .x = 4, .y = 10 },
            Pos{ .x = 4, .y = 11 },
            Pos{ .x = 3, .y = 12 },
            Pos{ .x = 3, .y = 13 },
        },
        result,
    );
}

test "should draw shallow line up-left" {
    const start = Pos{ .x = 11, .y = 7 };
    const end = Pos{ .x = 5, .y = 9 };

    const result = drawLine(start, end, &test_draw_line_buf);

    try std.testing.expectEqualSlices(
        Pos,
        &.{
            Pos{ .x = 11, .y = 7 },
            Pos{ .x = 10, .y = 7 },
            Pos{ .x = 9, .y = 8 },
            Pos{ .x = 8, .y = 8 },
            Pos{ .x = 7, .y = 8 },
            Pos{ .x = 6, .y = 9 },
            Pos{ .x = 5, .y = 9 },
        },
        result,
    );
}
