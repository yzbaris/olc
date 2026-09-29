const std = @import("std");
const rl = @import("raylib");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn format(
        self: Vec2,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Vec2{{ x: {}, y: {} }}", .{ self.x, self.y });
    }

    pub fn zero() Vec2 {
        return .{ .x = 0, .y = 0 };
    }

    pub fn length(self: Vec2) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn dist(self: Vec2, other: Vec2) f32 {
        return other.sub(self).length();
    }

    pub fn normalized(self: Vec2) Vec2 {
        const len = self.length();

        if (len == 0) return Vec2.zero();

        return .{
            .x = self.x / len,
            .y = self.y / len,
        };
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .init(self.x + other.x, self.y + other.y);
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .init(self.x - other.x, self.y - other.y);
    }

    pub fn scale(self: Vec2, amount: f32) Vec2 {
        return .init(self.x * amount, self.y * amount);
    }

    pub fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
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

    pub fn from_rl(rl_vec: rl.Vector2) Vec2 {
        return .init(rl_vec.x, rl_vec.y);
    }

    pub fn to_rl(self: Vec2) rl.Vector2 {
        return .init(self.x, self.y);
    }

    pub fn move_toward(source: Vec2, target: Vec2, delta: f32) Vec2 {
        const diff = target.sub(source);
        const distance = diff.length();

        if (distance <= delta or distance == 0) {
            return target;
        }

        return source.add(diff.scale(delta / distance));
    }
};
