pub const Pixel = struct {
    r: ?u8 = null,
    g: ?u8 = null,
    b: ?u8 = null,
    a: ?u8 = null,

    const Self = @This();

    pub fn allNull(self: Self) bool {
        return self.r == null and self.g == null and self.b == null and self.a == null;
    }

    pub fn check(self: Self, other: Pixel) bool {
        return (self.r == undefined or other.r == undefined or self.r == other.r) and (self.g == undefined or other.g == undefined or self.g == other.g) and (self.b == undefined or other.b == undefined or self.b == other.b) and (self.a == undefined or other.a == undefined or self.a == other.a);
    }
};
