//! this module holds the quadtree and cells for world calculations
const std = @import("std");
const sdl = @import("sdl.zig").lib;

const stack = @import("stack.zig");
const body = @import("body.zig");
const draw = @import("draw.zig");

const max_bodies: u32 = 4000;

/// quadtree node type
const Cell = struct {
    /// half the width of the cell
    half_width: f32,
    /// half the height of the cell
    half_height: f32,
    /// x position of the centre of the cell
    x_pos: f32,
    /// y position of the centre of the cell
    y_pos: f32,

    /// ratio of s/d
    ratio: f32,

    /// how many bodies are in this immediate cell
    count: u32,
    /// index of the bodies in this cell
    bodies: [capacity]u32,

    /// total mass in the cell
    mass: f32,
    /// x position of the cell's centre of gravity
    cog_x: f32,
    /// y position of the cell's centre of gravity
    cog_y: f32,

    /// does the cell have children?
    divided: bool,
    /// total bodies inside this box
    children: u32,
    /// child cells : NE, NW, SE, SW
    quadrants: [4]u32,

    const capacity: u32 = 6;

    pub fn inbounds(self: *Cell, x: f32, y: f32) bool {
        return
            (x > self.x_pos - self.half_width) and
            (x <= self.x_pos + self.half_width) and
            (y > self.y_pos - self.half_height) and
            (y <= self.y_pos + self.half_height);
    }

    pub fn init(self: *Cell) void {
        self.count = 0;
        self.children = 0;
        self.mass = 0;
        self.cog_x = 0;
        self.cog_y = 0;
        self.ratio = std.math.nan(f32);
        self.divided = false;
    }

    pub fn add_body(self: *Cell, b: u32) void {
        self.bodies[self.count] = b;
        self.count += 1;
    }

};

/// quadtree containing all bodies
/// call update(dt) to update all bodies it has
/// call render_bodies(renderer) to draw all bodies
/// call render_grid(renderer) to draw all boxes
pub const Quadtree = struct {

    allocator: std.mem.Allocator,

    /// count of how many nodes are being used
    index: u32,
    /// index of root node
    root: u32,

    /// width of the initial quadtree (can be expanded)
    width: f32,
    /// height of the initial quadtree (can be expanded)
    height: f32,

    /// master list of bodies
    bodies: body.Bodies(max_bodies),

    /// master list of cells
    cells: [3 * max_bodies]Cell,

    /// stack to do DFS without recursion or allocation
    stack: stack.Stack(u32, 3 * max_bodies + Cell.capacity),

    /// initialize the quadtree with the given width and height
    pub fn init(self: *Quadtree, allocator: std.mem.Allocator, width: f32, height: f32) void {
        //std.debug.print("[{s}:{d}] initializing quadtree\n", .{@src().file, @src().line});

        self.allocator = allocator;

        self.width = width;
        self.height = height;

        self.reset();

        self.bodies = undefined;
        self.bodies.init();
    }

    pub fn deinit(self: *Quadtree) void {
        std.heap.c_allocator.free(self.bodies);
    }

    /// create a new cell
    /// calls cell.init()
    /// increments self.index
    pub fn new_cell(self: *Quadtree) u32 {
        self.cells[self.index].init();
        self.index += 1;
        return self.index - 1;
    }

    /// update the quadtree
    /// updates the bodies in the tree and rebuilds
    pub fn update(self: *Quadtree, dt: f32) void {
        _ = dt;
        self.rebuild();
    }

    ///
    pub fn reset(self: *Quadtree) void {

        // clear out all cells
        self.index = 0;

        //std.debug.print("[{s}:{d}] resetting tree {d}\n", .{@src().file, @src().line, self.index});

        // create new root cell
        self.root = self.new_cell();

        // set root to be the size of the world
        self.cells[self.root].half_width = self.width * 0.5;
        self.cells[self.root].half_height = self.height * 0.5;
        // centers the root at the centre of the world
        // eventually make the centre be 0, 0
        self.cells[self.root].x_pos = self.width * 0.5;
        self.cells[self.root].y_pos = self.height * 0.5;
    }

    pub fn rebuild(self: *Quadtree) void {

        // clear out the tree
        self.reset();

        // reinsert all bodies
        var b: u32 = 0;
        while (b < self.bodies.count) : (b += 1) {
            try self.insert(b);
        }

        // recalculate all cell gravity stuffs
        self.recalculate();

    }

    pub fn recalculate(self: *Quadtree) void {
        //std.debug.print("[{s}:{d}] recalculating tree {d}\n", .{@src().file, @src().line, self.index});
        self.stack.push(self.root);

        while (!self.stack.isEmpty()) {
            // top stack item, pops later once children are done
            const top = try self.stack.peek();

            if (self.cells[top].divided) {

                // go through the cell's children and add to the parent
                var i: u32 = 0;
                if (std.math.isNan(self.cells[top].cog_x)) {
                    while (i < 4) : (i += 1) {
                        self.stack.push(self.cells[top].quadrants[i]); // add uncalculated child to the stack 
                    }
                    continue;
                }

                // if children have been calculated
                var j: u32 = 0;
                while (j < 4) : (j += 1) {
                    self.cells[top].mass += self.bodies.m[self.cells[top].quadrants[j]];
                    self.cells[top].cog_x += self.bodies.sx[self.cells[top].quadrants[j]];
                    self.cells[top].cog_y += self.bodies.sy[self.cells[top].quadrants[j]];
                }
                self.cells[top].cog_x = self.cells[top].cog_x / @as(f32,@floatFromInt(j));
                self.cells[top].cog_y = self.cells[top].cog_y / @as(f32,@floatFromInt(j));

                _ = try self.stack.pop(); // remove top cell from the stack as it has been calculated

            } else { // not divided
                self.cells[top].mass = 0;
                self.cells[top].cog_x = 0;
                self.cells[top].cog_y = 0;

                var i: u32 = 0;
                while (i < self.cells[top].count) : (i += 1) {
                    self.cells[top].mass += self.bodies.m[self.cells[top].bodies[i]];
                    self.cells[top].cog_x += self.bodies.sx[self.cells[top].bodies[i]];
                    self.cells[top].cog_y += self.bodies.sy[self.cells[top].bodies[i]];

                }
                if (i > 0) {
                    self.cells[top].cog_x = self.cells[top].cog_x / @as(f32,@floatFromInt(i));
                    self.cells[top].cog_y = self.cells[top].cog_y / @as(f32,@floatFromInt(i));
                }
                _ = try self.stack.pop(); // remove top cell from the stack as it has been calculated

            }
        }

    }

    pub fn insert(self: *Quadtree, body_: u32) !void {
        if (self.cells[self.root].inbounds(self.bodies.sx[body_], self.bodies.sy[body_])) {
            return self.insert_at(self.root, body_);
        } else {
            // if body is outside of tree then just ignore it
            return;
        }
    }

    fn insert_at(self: *Quadtree, start_node: u32, body_: u32) void {
        const body_x = self.bodies.sx[body_];
        const body_y = self.bodies.sy[body_];

        var node = start_node;
        var inserted = false;

        // assumes body is contained in this node
        while (!inserted) {

            // check if this cell is a leaf or a branch
            if (self.cells[node].divided) {
                
                // add this cell's values to the branch
                self.cells[node].children += 1;
                self.cells[node].mass += self.bodies.m[body_];
                self.cells[node].cog_x += body_x * self.bodies.m[body_];
                self.cells[node].cog_y += body_y * self.bodies.m[body_];

                var quadrant: u32 = 0; // child cells : NE, NW, SE, SW
                if (body_x < self.cells[node].x_pos) quadrant |= 1;
                if (body_y < self.cells[node].y_pos) quadrant |= 2;

                // loop again in child node
                node = self.cells[node].quadrants[quadrant];

            } else {
                // insert the cell, if it can't be inserted subdivide and loop again
                if (self.cells[node].count >= Cell.capacity) {
                    _ = self.subdivide(node);
                    continue;
                } else {
                    self.cells[node].add_body(body_);
                    inserted = true;
                }
            }
        }
    }

    fn subdivide(self: *Quadtree, node: u32) bool {
        if (self.cells[node].divided) return false; // return
        //std.debug.print("[{s}:{d}] subdividing node {d}, with {d} bodies, self.index = {d}\n", .{@src().file, @src().line, node, self.cells[node].count, self.index});

        const cx = self.cells[node].x_pos;
        const cy = self.cells[node].y_pos;
        const hw = self.cells[node].half_width * 0.5;
        const hh = self.cells[node].half_height * 0.5;

        self.cells[node].divided = true;

        // just do them all manually rather than loop :shrug:

        // NE
        self.cells[node].quadrants[0] = self.new_cell();
        self.cells[self.cells[node].quadrants[0]].half_width = hw;
        self.cells[self.cells[node].quadrants[0]].half_height = hh;
        self.cells[self.cells[node].quadrants[0]].x_pos = cx + hw;
        self.cells[self.cells[node].quadrants[0]].y_pos = cy + hh;

        // NW
        self.cells[node].quadrants[1] = self.new_cell();
        self.cells[self.cells[node].quadrants[1]].half_width = hw;
        self.cells[self.cells[node].quadrants[1]].half_height = hh;
        self.cells[self.cells[node].quadrants[1]].x_pos = cx - hw;
        self.cells[self.cells[node].quadrants[1]].y_pos = cy + hh;

        // SE
        self.cells[node].quadrants[2] = self.new_cell();
        self.cells[self.cells[node].quadrants[2]].half_width = hw;
        self.cells[self.cells[node].quadrants[2]].half_height = hh;
        self.cells[self.cells[node].quadrants[2]].x_pos = cx + hw;
        self.cells[self.cells[node].quadrants[2]].y_pos = cy - hh;

        // SW
        self.cells[node].quadrants[3] = self.new_cell();
        self.cells[self.cells[node].quadrants[3]].half_width = hw;
        self.cells[self.cells[node].quadrants[3]].half_height = hh;
        self.cells[self.cells[node].quadrants[3]].x_pos = cx - hw;
        self.cells[self.cells[node].quadrants[3]].y_pos = cy - hh;

        for (0..self.cells[node].count) |i| {
            const b = self.cells[node].bodies[i];
            const bx = self.bodies.sx[b];
            const by = self.bodies.sy[b];

            var q: u32 = 0;
            if (bx < cx) q |= 1;
            if (by < cy) q |= 2;

            self.insert_at(self.cells[node].quadrants[q], b);
        }

        self.cells[node].children = self.cells[node].count;
        self.cells[node].count = 0;

        return true;

    }

    pub fn render_bodies(self: *Quadtree, renderer: ?*anyopaque) void {
        self.bodies.renderAll(renderer);
    }

    pub fn render_grid(self: *Quadtree, renderer: ?*anyopaque) void {
    
        // exterior box
        draw.debug_line(
            renderer,
            self.cells[self.root].x_pos + self.cells[self.root].half_width,
            self.cells[self.root].y_pos + self.cells[self.root].half_height,
            self.cells[self.root].x_pos - self.cells[self.root].half_width,
            self.cells[self.root].y_pos + self.cells[self.root].half_height,
            .{ .r = 204, .g = 77, .b = 230 });
        
        draw.debug_line(
            renderer,
            self.cells[self.root].x_pos + self.cells[self.root].half_width,
            self.cells[self.root].y_pos - self.cells[self.root].half_height,
            self.cells[self.root].x_pos - self.cells[self.root].half_width,
            self.cells[self.root].y_pos - self.cells[self.root].half_height,
            .{ .r = 204, .g = 77, .b = 230 });
        
        draw.debug_line(
            renderer,
            self.cells[self.root].x_pos - self.cells[self.root].half_width,
            self.cells[self.root].y_pos + self.cells[self.root].half_height,
            self.cells[self.root].x_pos - self.cells[self.root].half_width,
            self.cells[self.root].y_pos - self.cells[self.root].half_height,
            .{ .r = 204, .g = 77, .b = 230 });
        
        draw.debug_line(
            renderer,
            self.cells[self.root].x_pos + self.cells[self.root].half_width,
            self.cells[self.root].y_pos + self.cells[self.root].half_height,
            self.cells[self.root].x_pos + self.cells[self.root].half_width,
            self.cells[self.root].y_pos - self.cells[self.root].half_height,
            .{ .r = 204, .g = 26, .b = 230 });

        // loop and render inside boxes
        for (0..self.index) |i| {
            // horizontal line
            draw.debug_line(
                renderer,
                self.cells[i].x_pos + self.cells[i].half_width,
                self.cells[i].y_pos,
                self.cells[i].x_pos - self.cells[i].half_width,
                self.cells[i].y_pos,
                .{ .r = 26, .g = 204, .b = 230 });
            
            // vertical line
            draw.debug_line(
                renderer,
                self.cells[i].x_pos,
                self.cells[i].y_pos + self.cells[i].half_height,
                self.cells[i].x_pos,
                self.cells[i].y_pos - self.cells[i].half_height,
                .{ .r = 26, .g = 204, .b = 230 });
        }
    }

};