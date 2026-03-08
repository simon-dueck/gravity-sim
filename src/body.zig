//! this module holds the bodies type and associated integration values
const std = @import("std");
const sdl = @import("sdl.zig").lib;

const draw = @import("draw.zig");

pub fn Bodies(capacity: u32) type {
    return struct {
        const Self: type = @This();
        const Vec: type = @Vector(capacity, f32);

        const sides = 10;

        capacity: u32,
        count: u32,

        /// X position for each body
        sx: Vec,
        /// Y position for each body
        sy: Vec,
        /// X velocity for each body
        vx: Vec,
        /// Y velocity for each body
        vy: Vec,
        /// X acceleration for each body
        ax: Vec,
        /// Y acceleration for each body
        ay: Vec,
        /// Mass for each body
        m: Vec,
        /// Radius for each body
        r: Vec,

        /// temporary vectors for use in intermediate calculations
        v1: Vec,
        v2: Vec,
        v3: Vec,
        v4: Vec,

        /// Polygon Meshes for each body
        mesh: [capacity]draw.PolygonMesh,

        // // other properies that might be useful later??
        // const VecB: type = @Vector(count, u8);
        // t: VecB, // type: rocky, gas, idk this might be useful for colours or something
        // u: Vec, // stored energy
        // h: Vec, // hardness/toughness or something
        // e: Vec, // elasticity/restitution

        /// calculates the total kinetic energy of the bodies
        pub fn energy(self: *Self) f32 {
            self.v4 = self.m * @sqrt(self.vx * self.vx + self.vy + self.vy);
            return 0.5 * @reduce(.Add, self.v1);
        }

        pub fn verlet(self: *Self, dt: f32) void {
            self.sx = self.sx + self.vx * @as(Vec, @splat(dt)) + self.ax * @as(Vec, @splat(0.5 * dt * dt));
            self.sy = self.sy + self.vy * @as(Vec, @splat(dt)) + self.ay * @as(Vec, @splat(0.5 * dt * dt));

            self.vx = self.vx + (self.ax + self.v1) * @as(Vec, @splat(0.5 * dt));
            self.vy = self.vy + (self.ay + self.v2) * @as(Vec, @splat(0.5 * dt));

            self.ax = self.v1;
            self.ay = self.v2;
        }

        pub fn scalePos(self: *Self, min_x: f32, max_x: f32, min_y: f32, max_y: f32) void {
            self.sx = self.sx * @as(Vec, @splat(max_x - min_x)) + @as(Vec, @splat(min_x));
            self.sy = self.sy * @as(Vec, @splat(max_y - min_y)) + @as(Vec, @splat(min_y));
        }

        pub fn init(self: *Self) void {
            std.debug.print("[{s}:{d}] initializing bodies\n", .{@src().file, @src().line});
            self.capacity = capacity;
            self.count = 0;
        }

        pub fn addRandomBody(self: *Self, rng: std.Random) !void {
            return try self.addBody(rng.float(f32), rng.float(f32), rng.float(f32), rng.float(f32), rng.float(f32), rng.float(f32), rng.float(f32), rng.float(f32));
        }

        pub fn addBody(self: *Self, sx: f32, sy: f32, vx: f32, vy: f32, ax: f32, ay: f32, m: f32, r: f32) !void {
            if (self.count >= self.capacity) return error.OutOfCapacity;

            self.sx[self.count] = sx;
            self.sy[self.count] = sy;
            self.vx[self.count] = vx;
            self.vy[self.count] = vy;
            self.ax[self.count] = ax;
            self.ay[self.count] = ay;
            self.m[self.count] = m;
            self.r[self.count] = r;

            self.mesh[self.count].init(sides);

            self.count += 1;
        }

        pub fn removeBody(self: *Self, body: u32) void {
            self.count -= 1;
            self.swap(body, self.count);
        }

        pub fn clear(self: *Self) void {
            self.count = 0;
        }

        fn swap(self: *Self, a: u32, b: u32) void {
            std.mem.swap(f32, &self.sx[a], &self.sx[b]);
            std.mem.swap(f32, &self.sy[a], &self.sy[b]);
            std.mem.swap(f32, &self.vx[a], &self.vx[b]);
            std.mem.swap(f32, &self.vy[a], &self.vy[b]);
            std.mem.swap(f32, &self.ax[a], &self.ax[b]);
            std.mem.swap(f32, &self.ay[a], &self.ay[b]);
            std.mem.swap(f32, &self.m[a], &self.m[b]);
            std.mem.swap(f32, &self.r[a], &self.r[b]);
            std.mem.swap(f32, &self.mesh[a], &self.mesh[b]);
        }

        pub fn shuffle(self: *Self, rng: std.Random) void {
            for (0..self.count) |i| {
                //const j: @TypeOf(self.count) = @truncate(i);
                self.swap(@truncate(i), @intFromFloat(i + rng.int(f32) * (self.count - i)));
            }
        }

        pub fn renderAll(self: *Self, renderer: ?*anyopaque) void {
            for (0..self.count) |i| self.renderBody(@truncate(i), renderer);
        }

        pub fn renderBody(self: *Self, body: u32, renderer: ?*anyopaque) void {
            (&self.mesh[body]).solid(renderer, self.sx[body], self.sy[body], self.r[body], 0, .{ .r = 0.9, .g = 0.9, .b = 0.9,});
        }

    };
}

test "init bodies" {
    const k = 5;

    var prng = std.Random.DefaultPrng.init(k);
    const rng = prng.random();

    var bodies: Bodies(k) = undefined;
    bodies.init(rng);

    bodies.scalePos(-5, -4, 7, 8);

    std.debug.print("\nsx {any}\n", .{bodies.sx});
    std.debug.print("sy {any}\n", .{bodies.sy});

    const dt = 1;
    const a = @as(Bodies(k).Vec, @splat(2));

    bodies.verlet(a, a, dt);
    bodies.verlet(a, a, dt);
    bodies.verlet(a, a, dt);
    bodies.verlet(a, a, dt);

    std.debug.print("\nsx {any}\n", .{bodies.sx});
    std.debug.print("sy {any}\n", .{bodies.sy});
}
