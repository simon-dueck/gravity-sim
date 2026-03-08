//! this module holds the world type containing all data for the simulation
const std = @import("std");
const Io = @import("Io");

const sdl = @import("sdl.zig").lib;

const body = @import("body.zig");
const draw = @import("draw.zig");
const qt = @import("quadtree.zig");
const bh = @import("barnes-hut.zig");

pub const World = struct {
    
    pub const G: f32 = 1;
    pub const eps: f32 = 1e-4;
    pub const theta: f32 = 0.5;

    allocator: std.mem.Allocator,
    
    /// background colour
    bg_colour: sdl.SDL_Color,

    /// should the world draw its bodies
    draw_bodies: bool,
    /// should the world draw its quadtree boxes
    draw_qtree: bool,
    /// should gravity be calculated
    gravity: bool,
    /// should collisions be enabled
    collisions: bool,

    /// tree containing world objects
    quadtree: qt.Quadtree,

    /// renderer for each
    renderer: *sdl.SDL_Renderer,

    pub fn init(self: *World, allocator: std.mem.Allocator, width: f32, height: f32, renderer: ?*anyopaque) void {
        //std.debug.print("[{s}:{d}] initializing world\n", .{@src().file, @src().line});

        self.allocator = allocator;

        self.bg_colour = .{ .r = 26, .g = 26, .b = 38, .a = 25 };

        self.draw_bodies = true;
        self.draw_qtree = true;
        self.gravity = true;
        self.collisions = false;

        self.renderer = @ptrCast(renderer);

        self.quadtree.init(allocator, width, height);

    }

    pub fn toggle_bodies(self: *World) void { self.draw_bodies = !self.draw_bodies; }
    pub fn toggle_tree(self: *World) void { self.draw_qtree = !self.draw_qtree; }
    pub fn toggle_gravity(self: *World) void { self.gravity = !self.gravity; }
    pub fn toggle_collisions(self: *World) void { self.collisions = !self.collisions; }

    pub fn render(self: *World) void {

        // fill the background
        draw.background_fill(self.renderer, self.bg_colour);

        if (self.draw_qtree) {
            self.quadtree.render_grid(self.renderer);
        }
        if (self.draw_bodies) {
            self.quadtree.render_bodies(self.renderer);
        }

        std.Thread.sleep((1/200) * std.time.ns_per_s);

    }

    pub fn update(self: *World, dt: f32) void {
        //std.debug.print("[{s}:{d}] updating world\n", .{@src().file, @src().line});
        
        _ = self; _ = dt;

        std.Thread.sleep((1/1000) * std.time.ns_per_s);
        
        //self.quadtree.update(dt);
        //if (self.collisions) {
        //    // do collisions
        //}
        //if (self.gravity) {
        //    bh.barnes_hut(self, dt);
        //}
    }

};