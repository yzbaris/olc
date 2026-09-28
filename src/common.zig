pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn zero() Vec2 {
        return .{ .x = 0, .y = 0 };
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .init(self.x + other.x, self.y + other.y);
    }

    pub fn scale(self: Vec2, amount: f32) Vec2 {
        return .init(self.x * amount, self.y * amount);
    }

    pub fn dot(self: Vec2, other: *Vec2) Vec2 {
        return .init(self.x * other.x, self.y * other.y);
    }

    pub fn eq(self: Vec2, other: Vec2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn is_zero(self: Vec2) bool {
        return self.x == 0 and self.y == 0;
    }

    pub fn setx(self: *Vec2, value: f32) void {
        self.x = value;
    }

    pub fn addx(self: *Vec2, value: f32) void {
        self.x += value;
    }

    pub fn sety(self: *Vec2, value: f32) void {
        self.y = value;
    }

    pub fn addy(self: *Vec2, value: f32) void {
        self.y += value;
    }
};
