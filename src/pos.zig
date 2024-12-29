pub const Pos = struct {
    x: usize,
    y: usize,

    const Self = @This();

    pub fn dist(self: Self, other: Pos) f32 {
        const x_max: f32 = @floatFromInt(@max(self.x, other.x));
        const x_min: f32 = @floatFromInt(@min(self.x, other.x));
        const y_max: f32 = @floatFromInt(@max(self.y, other.y));
        const y_min: f32 = @floatFromInt(@min(self.y, other.y));

        return @sqrt(square(x_max - x_min) + square(y_max - y_min));
    }

    fn square(x: f32) f32 {
        return x * x;
    }
};
