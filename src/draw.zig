const std = @import("std");
const sdl = @import("sdl.zig").lib;

pub const PolygonMesh = struct {
    const max_segments = 64; // adjust later, maybe make this variable?

    source_vertices: [max_segments + 2]sdl.SDL_Vertex,
    work_vertices: [max_segments + 2]sdl.SDL_Vertex,
    indices: [max_segments * 3]c_int,

    vert_count: c_int,
    index_count: c_int,

    pub fn init(self: *PolygonMesh, segments: u31) void {

        std.debug.assert(segments <= max_segments);

        // centre point
        self.source_vertices[0] = .{
            .position = .{ .x = 0, .y = 0 },
            .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
            .tex_coord = .{ .x = 0, .y = 0 },
        };

        self.work_vertices[0] = .{
            .position = .{ .x = 0, .y = 0 },
            .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
            .tex_coord = .{ .x = 0, .y = 0 },
        };

        const inv_segments = 2 / @as(f32, @floatFromInt(segments));

        // vertices around the outside
        var i: @TypeOf(segments) = 0;
        while (i <= segments) : (i += 1) {
            const angle = std.math.pi *  @as(f32, @floatFromInt(i)) * inv_segments;
            self.source_vertices[i + 1] = .{
                .position = .{
                    .x = std.math.cos(angle),
                    .y = std.math.sin(angle),
                },
                .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
                .tex_coord = .{ .x = 0, .y = 0 },
            };
            self.work_vertices[i + 1] = .{
                .position = .{
                    .x = std.math.cos(angle),
                    .y = std.math.sin(angle),
                },
                .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
                .tex_coord = .{ .x = 0, .y = 0 },
            };
        }

        var j: @TypeOf(segments) = 0;
        var k: @TypeOf(segments) = 0;
        while (j < segments) : (j += 1) {
            self.indices[k + 0] = 0; // centre vertex
            self.indices[k + 1] = @as(c_int, j + 1);
            self.indices[k + 2] = @as(c_int, j + 2);
            k += 3;
        }

        self.vert_count = @as(c_int, segments) + 2;
        self.index_count = @as(c_int, segments) * 3;
    }

    pub fn outline(self: *PolygonMesh, renderer: ?*anyopaque, cx: f32, cy: f32, radius: f32, rotation: f32, colour: sdl.SDL_FColor) void {
        const cos_r = @cos(rotation);
        const sin_r = @sin(rotation);

        var i: usize = 1; // skip 0, as the centre vertex isn't needed
        while (i < self.vert_count) : (i += 1) {
            const src = self.source_vertices[i];
            var v = &self.work_vertices[i];

            const rx = src.position.x * cos_r - src.position.y * sin_r;
            const ry = src.position.x * sin_r + src.position.y * cos_r;

            v.position.x = cx + rx * radius;
            v.position.y = cy + ry * radius;
        }

        _ = sdl.SDL_SetRenderDrawColorFloat(renderer, colour.r, colour.g, colour.b, colour.a);

        i = 1;
        while (i < self.vert_count - 1) : (i += 1) {
            const a = self.work_vertices[i].position;
            const b = self.work_vertices[i + 1].position;

            _ = sdl.SDL_RenderLine(
                renderer,
                a.x, a.y,
                b.x, b.y,
            );
        }
    }

    pub fn outline_batched(self: *PolygonMesh, renderer: ?*anyopaque, cx: f32, cy: f32, radius: f32, rotation: f32, thickness: f32, colour: sdl.SDL_FColor) void {
        const cos_r = @cos(rotation);
        const sin_r = @sin(rotation);
        const half = thickness * 0.5;

        // Transform outer vertices
        var i: usize = 1;
        while (i < self.vert_count) : (i += 1) {
            const src = self.source_vertices[i];
            var v = &self.work_vertices[i];

            const rx = src.position.x * cos_r - src.position.y * sin_r;
            const ry = src.position.x * sin_r + src.position.y * cos_r;

            v.position.x = cx + rx * radius;
            v.position.y = cy + ry * radius;
        }

        var v_cursor: usize = 0;
        var i_cursor: usize = 0;

        i = 1;
        while (i < self.vert_count - 1) : (i += 1) {
            const a = self.work_vertices[i].position;
            const b = self.work_vertices[i + 1].position;

            // Edge direction
            var dx = b.x - a.x;
            var dy = b.y - a.y;
            const len = @sqrt(dx * dx + dy * dy);
            if (len == 0) continue;

            dx /= len;
            dy /= len;

            // Perpendicular normal
            const nx = -dy * half;
            const ny =  dx * half;

            // Quad vertices
            self.outline_vertices[v_cursor + 0] = .{
                .position = .{ .x = a.x + nx, .y = a.y + ny },
                .color = colour,
                .tex_coord = .{ .x = 0, .y = 0 },
            };
            self.outline_vertices[v_cursor + 1] = .{
                .position = .{ .x = a.x - nx, .y = a.y - ny },
                .color = colour,
                .tex_coord = .{ .x = 0, .y = 0 },
            };
            self.outline_vertices[v_cursor + 2] = .{
                .position = .{ .x = b.x - nx, .y = b.y - ny },
                .color = colour,
                .tex_coord = .{ .x = 0, .y = 0 },
            };
            self.outline_vertices[v_cursor + 3] = .{
                .position = .{ .x = b.x + nx, .y = b.y + ny },
                .color = colour,
                .tex_coord = .{ .x = 0, .y = 0 },
            };

            // Indices
            self.outline_indices[i_cursor + 0] = @intCast(v_cursor + 0);
            self.outline_indices[i_cursor + 1] = @intCast(v_cursor + 1);
            self.outline_indices[i_cursor + 2] = @intCast(v_cursor + 2);

            self.outline_indices[i_cursor + 3] = @intCast(v_cursor + 0);
            self.outline_indices[i_cursor + 4] = @intCast(v_cursor + 2);
            self.outline_indices[i_cursor + 5] = @intCast(v_cursor + 3);

            v_cursor += 4;
            i_cursor += 6;
        }

        self.outline_vert_count = @intCast(v_cursor);
        self.outline_index_count = @intCast(i_cursor);

        // Single GPU draw call
        _ = sdl.SDL_RenderGeometry(
            renderer,
            null,
            &self.outline_vertices,
            self.outline_vert_count,
            &self.outline_indices,
            self.outline_index_count,
        );
    }

    pub fn solid(self: *PolygonMesh, renderer: ?*anyopaque, cx: f32, cy: f32, radius: f32, rotation: f32, colour: sdl.SDL_FColor) void {
        const cos_r = @cos(rotation);
        const sin_r = @sin(rotation);
        
        var i: usize = 0;
        while (i < self.vert_count) : (i += 1) {
            const src = self.source_vertices[i];
            var v = &self.work_vertices[i];

            const rx = src.position.x * cos_r - src.position.y * sin_r;
            const ry = src.position.x * sin_r + src.position.y * cos_r;

            v.position.x = cx + rx * radius;
            v.position.y = cy + ry * radius;

            v.color = colour;
        }

        _ = sdl.SDL_RenderGeometry(
            @ptrCast(renderer),
            null,
            &self.work_vertices,
            @as(c_int, @as(c_int, self.vert_count)),
            &self.indices,
            @as(c_int, self.index_count),
        );
    }

};

/// fills the background with the given colour
pub fn background_fill(renderer: ?*anyopaque, colour: sdl.SDL_Color) void {
    _ = sdl.SDL_SetRenderDrawColor(@ptrCast(renderer), colour.r, colour.g, colour.b, 255);
    _ = sdl.SDL_RenderClear(@ptrCast(renderer));
}

pub fn line(renderer: ?*anyopaque, x1: f32, y1: f32, x2: f32, y2: f32, thickness: f32, colour: sdl.SDL_FColor) void {
    
    // TODO make thin line code work better
    //if (thickness <= 1) {
    //    debug_line(renderer, x1, y1, x2, y2, colour);
    //}

    const dx = x2 - x1;
    const dy = y2 - y1;

    const len_sq = dx * dx + dy * dy;
    if (len_sq < 1e5) { // zero lengh, don't draw anything
        @branchHint(.unlikely);
        return;
    }
    const len = @sqrt(len_sq);

    const ux = dx / len;
    const uy = dy / len;

    const half = thickness * 0.5;

    const nx = -uy * half;
    const ny = ux * half;

    var verts = [_]sdl.SDL_Vertex{
        .{
            .position = .{ .x = x1 + nx, .y = y1 + ny },
            .color = colour,
            .tex_coord = .{ .x = 0, .y = 0 },
        },
        .{
            .position = .{ .x = x1 - nx, .y = y1 - ny },
            .color = colour,
            .tex_coord = .{ .x = 0, .y = 0 },
        },
        .{
            .position = .{ .x = x2 - nx, .y = y2 - ny },
            .color = colour,
            .tex_coord = .{ .x = 0, .y = 0 },
        },
        .{
            .position = .{ .x = x2 + nx, .y = y2 + ny },
            .color = colour,
            .tex_coord = .{ .x = 0, .y = 0 },
        },
    };

    const indices = [_]c_int{
        0,1,2, 0,2,3,
    };

    _ = sdl.SDL_RenderGeometry(
        @ptrCast(renderer),
        null,
        &verts,
        @as(c_int, 4),
        &indices,
        @as(c_int, 6),
    );

}

pub fn debug_line(renderer: ?*anyopaque, x1: f32, y1: f32, x2: f32, y2: f32, colour: sdl.SDL_Color) void {
    _ = sdl.SDL_SetRenderDrawColor(@ptrCast(renderer), colour.r, colour.g, colour.b, 255);

    _ = sdl.SDL_RenderLine(@ptrCast(renderer), x1, y1, x2, y2);
}
