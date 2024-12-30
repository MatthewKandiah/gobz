const std = @import("std");
const RenderInfo = @import("render_info.zig");
const FullRenderInfo = RenderInfo.FullRenderInfo;
const DenseRenderInfo = RenderInfo.DenseRenderInfo;
const Pos = @import("pos.zig").Pos;
const Dim = @import("dim.zig").Dim;
const Rect = @import("rect.zig").Rect;
const Pixel = @import("pixel.zig").Pixel;
const PixelFormat = @import("pixel_format.zig").PixelFormat;
const Colour = @import("colour.zig").Colour;
const Map = @import("map.zig").Map;

pub const Surface = struct {
    bytes: []u8,
    width_pixels: usize,
    height_pixels: usize,
    pixel_format: PixelFormat,

    const Self = @This();

    pub fn clear(self: Self) void {
        for (self.bytes) |*b| {
            b.* = 0;
        }
    }

    pub fn drawFull(self: Self, input: FullRenderInfo, pos: Pos, clipping_rect: Rect, scale: usize, override_colour: ?Colour) void {
        var read_idx: usize = 0;
        var read_pixel_col: usize = 0;
        var read_pixel_row: usize = 0;
        while (read_idx <= input.data.len - 4) {
            const r = input.data[read_idx];
            const g = input.data[read_idx + 1];
            const b = input.data[read_idx + 2];
            const a = input.data[read_idx + 3];

            const should_draw = !input.stencil_pixel.check(.{ .r = r, .g = g, .b = b, .a = a });
            if (should_draw) {
                for (0..scale) |scale_vertical_count| {
                    for (0..scale) |scale_horizontal_count| {
                        const write_pixel_idx = pos.x + scale_horizontal_count + (read_pixel_col * scale) + (pos.y + scale_vertical_count + (read_pixel_row * scale)) * self.width_pixels;
                        const write_pos = Pos{
                            .x = write_pixel_idx % self.width_pixels,
                            .y = write_pixel_idx / self.width_pixels,
                        };
                        if (clipping_rect.contains(write_pos)) {
                            const write_idx = write_pixel_idx * 4;
                            if (override_colour) |c| {
                                self.bytes[write_idx + self.pixel_format.r] = c.r;
                                self.bytes[write_idx + self.pixel_format.g] = c.g;
                                self.bytes[write_idx + self.pixel_format.b] = c.b;
                                self.bytes[write_idx + self.pixel_format.a] = a;
                            } else {
                                self.bytes[write_idx + self.pixel_format.r] = r;
                                self.bytes[write_idx + self.pixel_format.g] = g;
                                self.bytes[write_idx + self.pixel_format.b] = b;
                                self.bytes[write_idx + self.pixel_format.a] = a;
                            }
                        }
                    }
                }
            }

            read_idx += 4;
            read_pixel_col += 1;
            if (read_pixel_col >= input.width) {
                read_pixel_col = 0;
                read_pixel_row += 1;
            }
        }
    }

    pub fn drawDense(self: Self, input: DenseRenderInfo, pos: Pos, clipping_rect: Rect, scale: usize, override_colour: Colour) void {
        var read_idx: usize = 0;
        var read_pixel_col: usize = 0;
        var read_pixel_row: usize = 0;
        while (read_idx < input.data.len) {
            const should_draw = input.data[read_idx];
            if (should_draw) {
                for (0..scale) |scale_vertical_count| {
                    for (0..scale) |scale_horizontal_count| {
                        const write_pixel_idx = pos.x + scale_horizontal_count + (read_pixel_col * scale) + (pos.y + scale_vertical_count + (read_pixel_row * scale)) * self.width_pixels;
                        const write_pos = Pos{
                            .x = write_pixel_idx % self.width_pixels,
                            .y = write_pixel_idx / self.width_pixels,
                        };
                        if (clipping_rect.contains(write_pos)) {
                            const write_idx = write_pixel_idx * 4;
                            self.bytes[write_idx + self.pixel_format.r] = override_colour.r;
                            self.bytes[write_idx + self.pixel_format.g] = override_colour.g;
                            self.bytes[write_idx + self.pixel_format.b] = override_colour.b;
                            self.bytes[write_idx + self.pixel_format.a] = 255;
                        }
                    }
                }
            }

            read_idx += 1;
            read_pixel_col += 1;
            if (read_pixel_col >= input.width) {
                read_pixel_col = 0;
                read_pixel_row += 1;
            }
        }
    }

    pub fn drawMap(self: Self, map: Map, clipping_rect: Rect, sprite_dim_pixels: Dim, floor_tile_render_data: FullRenderInfo, player_pos: Pos, scale: usize) void {
        const player_sprite_pos = .{
            .x = clipping_rect.pos.x + clipping_rect.dim.width / 2 - sprite_dim_pixels.width / 2,
            .y = clipping_rect.pos.y + clipping_rect.dim.height / 2 - sprite_dim_pixels.height / 2,
        };
        for (0..map.dim_tiles.height) |j| {
            for (0..map.dim_tiles.width) |i| {
                const p = Pos{ .x = i, .y = j };
                const v = map.getVisibility(p);
                if (v == .Unknown) {
                    continue;
                }
                const map_cell = map.get(p) orelse @panic("should never happen");
                const maybe_render_data = switch (map_cell) {
                    .Floor => floor_tile_render_data,
                    .Wall => null,
                };
                if (maybe_render_data) |render_data| {
                    const ax = player_sprite_pos.x + i * sprite_dim_pixels.width;
                    const bx = player_pos.x * sprite_dim_pixels.width;
                    const ay = player_sprite_pos.y + j * sprite_dim_pixels.height;
                    const by = player_pos.y * sprite_dim_pixels.height;
                    if (ax >= bx and ay >= by) {
                        const x_idx = player_sprite_pos.x + i * sprite_dim_pixels.width - player_pos.x * sprite_dim_pixels.width;
                        const y_idx = player_sprite_pos.y + j * sprite_dim_pixels.height - player_pos.y * sprite_dim_pixels.height;
                        if (x_idx + sprite_dim_pixels.width < self.width_pixels and y_idx + sprite_dim_pixels.height < self.height_pixels) {
                            self.drawFull(
                                render_data,
                                .{ .x = x_idx, .y = y_idx },
                                clipping_rect,
                                scale,
                                if (v == .KnownNotVisible) .{ .r = 122, .g = 122, .b = 122 } else null,
                            );
                        }
                    }
                }
            }
        }
    }

    pub fn drawPlayer(self: Self, clipping_rect: Rect, sprite_dim_pixels: Dim, player_render_data: DenseRenderInfo, scale: usize) void {
        const player_sprite_pos = .{
            .x = clipping_rect.pos.x + clipping_rect.dim.width / 2 - sprite_dim_pixels.width / 2,
            .y = clipping_rect.pos.y + clipping_rect.dim.height / 2 - sprite_dim_pixels.height / 2,
        };
        self.drawDense(
            player_render_data,
            .{ .x = player_sprite_pos.x, .y = player_sprite_pos.y },
            clipping_rect,
            scale,
            .{ .r = 255, .g = 255, .b = 0 },
        );
    }
};
