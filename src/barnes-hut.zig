//! this module contains the logic for the barnes-hut algorithm
const std = @import("std");
const sdl = @import("sdl.zig").lib;

const body = @import("body.zig");
const World = @import("world.zig").World;

pub fn barnes_hut(world: *World, dt: f32) void {

    const qt = &world.quadtree;

    qt.bodies.v1 = @splat(0);
    qt.bodies.v2 = @splat(0);

    var i: u32 = 0;
    while (i < qt.bodies.count) : (i += 1) {
        const px = qt.bodies.sx[i];
        const py = qt.bodies.sy[i];
        
        var ax: f32 = 0;
        var ay: f32 = 0;

        qt.stack.init();
        qt.stack.push(qt.root);

        while (!qt.stack.isEmpty()) {
            const node = qt.stack.pop() catch unreachable;
            const cell = &qt.cells[node];

            if (cell.mass == 0) continue;
            
            const dx = cell.cog_x - px;
            const dy = cell.cog_y - py;

            const dist2 = dx * dx + dy * dy + World.eps;
            const s = @max(cell.half_width, cell.half_height) * 2;

            if (!cell.divided or (s * s)/dist2 < World.theta * World.theta) {
                const inv_r = 1 / @sqrt(dist2);
                const inv_r3 = inv_r * inv_r * inv_r;

                const f = World.G * cell.mass * inv_r3;
                ax += dx * f;
                ay += dy * f;
            } else {
                var q: u32 = 0;
                while (q < 4) : (q += 1) {
                    qt.stack.push(cell.quadrants[q]);
                }
            }

        }

        qt.bodies.v1[i] = ax;
        qt.bodies.v2[i] = ay;

    }

    qt.bodies.verlet(dt);

}