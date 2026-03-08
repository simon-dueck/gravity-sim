const std = @import("std");


test "nan" {

    const bits: u32 = 0b0111_1111_1000_0000_0000_0000_0000_0000;
    const float: f32 = @bitCast(bits);
    const nan = std.math.nan(f32);
    const nanbits: u32= @bitCast(nan);

    std.debug.print("\n\nvalue: {}, {}, {}, {}\n\n", .{bits, float, nanbits, nan});
}