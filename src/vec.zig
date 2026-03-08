const std = @import("std");

const Vec2 = struct {
    _v: @Vector(2, f32),

    pub fn zero() Vec2 {
        return .{ ._v = @splat(0) };
    }

    pub fn x(vec: Vec2) f32 {
        return vec._v[0];
    }

    pub fn y(vec: Vec2) f32 {
        return vec._v[1];
    }

    pub fn init(x_: f32, y_: f32) Vec2 {
        return .{ ._v = .{ x_, y_ } };
    }

    pub fn string(v: Vec2, allocator: std.mem.Allocator) []const u8 {
        return try std.fmt.allocPrint(allocator, "< {d}, {d} >", .{ v.x(), v.y() });
    }

    pub fn add(u: Vec2, v: Vec2) Vec2 {
        return .{ ._v = u._v + v._v };
    }

    pub fn sub(u: Vec2, v: Vec2) Vec2 {
        return .{ ._v = u._v - v._v };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return .{ ._v = .{ v.x() * s, v.y() * s } };
    }

    pub fn lengthSquared(v: Vec2) f32 {
        const u = v * v;
        return u.x() + u.y();
    }

    pub fn mag(v: Vec2) f32 {
        return @sqrt(v.lengthSquared());
    }
};
