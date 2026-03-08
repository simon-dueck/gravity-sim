const std = @import("std");

const sdl = @import("sdl.zig").lib;

const wld = @import("world.zig");
const draw = @import("draw.zig");
const body = @import("body.zig");

const kb_state = sdl.getKeyboardState(null);

const nanoseconds = u64;
const seconds = u64;
const hertz = u64;
const gigahertz = u64;

// ticks per second
const tps: u64 = 120;

const win_width = 1600;
const win_height = 900;

const buffer = 0;
const world_width = win_width - buffer;
const world_height = win_height - buffer;

var prng = std.Random.DefaultPrng.init(5);
const rng = prng.random();

var world: wld.World = undefined;

/// counts how many updates have passed
var update_count: u64 = 0;
var render_count: u64 = 0;
var prev_render_count: u64 = 0;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {

    const sdl_struct = try initSDL();

    defer sdl.SDL_Quit();
    defer sdl.SDL_DestroyRenderer(sdl_struct.renderer);
    defer sdl.SDL_DestroyWindow(sdl_struct.window);

    world.init(gpa.allocator(), world_width, world_height, sdl_struct.renderer);

    for (0..10) |_| {
        try world.quadtree.bodies.addRandomBody(rng);
    }

    world.quadtree.bodies.r += @splat(@as(f32, 100));
    world.quadtree.bodies.r *= @splat(@as(f32, 0.02));
    
    world.quadtree.bodies.sx *= @splat(@as(f32, world_width - buffer));
    world.quadtree.bodies.sx += @splat(@as(f32, buffer / 2));

    world.quadtree.bodies.sy *= @splat(@as(f32, world_height - buffer));
    world.quadtree.bodies.sy += @splat(@as(f32, buffer / 2));

    try run(tps, sdl_struct.renderer);

    return;
}

pub fn initSDL() !struct { window: *sdl.SDL_Window, renderer: *sdl.SDL_Renderer, } {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        @branchHint(.unlikely);
        return error.SDLInitFailed;
    }

    const window = sdl.SDL_CreateWindow(
        "gravity yay",
        win_width,
        win_height,
        sdl.SDL_WINDOW_RESIZABLE,
    ) orelse return error.WindowCreateFailed;

    const renderer = sdl.SDL_CreateRenderer(
        window,
        null, // driver name (null = default)
    ) orelse return error.RendererCreateFailed;

    _ = sdl.SDL_SetRenderVSync(renderer, @as(c_int, 0));

    return .{
        .window = window,
        .renderer = renderer,
    };
}

fn run(target_tps: seconds, renderer: *sdl.SDL_Renderer) !void {

    // target delta time in nanoseconds
    const target_dt: nanoseconds = std.time.ns_per_s / target_tps;
    const target_dt_float = @as(f32, @floatFromInt(target_dt));

    //std.debug.print("[{s}:{d}]\tframerate : {} fps = {} ns/frame\n", .{@src().file, @src().line, target_fps, target_dt_float});

    var timer = try std.time.Timer.start();

    var acc: u64 = 0; // used to trigger events that are only meant to happen every given interval

    const max_dt: nanoseconds = target_dt * 5;

    var running = true;
    var event: sdl.SDL_Event = undefined;

    // kill the program after a given length of time,
    // allows program to freeze but still close,
    // TODO: remove timeout condition once program is stable
    var timeout: u32 = 20000;

    // get initial time value
    var prev_time: nanoseconds = timer.read();

    // TODO: remove timeout condition once program is stable
    while (running and timeout > 0) : (timeout -= 1) {
        const now: nanoseconds = timer.read();
        var dt: nanoseconds = now - prev_time;
        prev_time = now;

        // Clamp frame time
        dt = @min(dt, max_dt);

        // accumulate delta time
        acc += dt;

        // once accumulator has reached the target duration, proc event loop, move accumulator down by a timestep
        while (acc >= target_dt) {
            // read input
            while (sdl.SDL_PollEvent(&event)) {
                switch (event.type) {
                    sdl.SDL_EVENT_QUIT => running = false,
                    sdl.SDL_EVENT_KEY_DOWN => {
                        const key = event.key;
                        if (key.scancode == sdl.SDL_SCANCODE_ESCAPE) running = false; 
                    },
                    else => continue,
                }
            }

            // update physics
            _ = try fixed_update(target_dt_float);

            // reset accumulator
            // don't clear it entirely, allows for some variance to average out
            acc -= target_dt;
        }

        // render frames as fast as possible, use alpha to tween the frames or something idk
        const alpha: f32 = @as(f32, @floatFromInt(acc)) / target_dt_float;
        _ = try render(target_dt_float,alpha, renderer);
    }
}

/// update the world with the given timestep in nanoseconds
fn fixed_update(dt: f32) !bool {
    update_count += 1;
    const fps = @as(f32, @floatFromInt(render_count - prev_render_count)) / (dt / std.time.ns_per_s);

    //std.debug.print("[{s}:{d}]\tdt : {}\n", .{@src().file, @src().line, dt});
    std.debug.print("[{s}:{d}]\tfps: {}\trenders : {}\tupdates : {}\n", .{@src().file, @src().line, fps, render_count, update_count});

    world.update(dt);

    return true;
}

/// Render the world with the given timestep in nanoseconds
fn render(dt: f32, alpha: f32, renderer: *sdl.SDL_Renderer) !bool {
    render_count += 1;

    //std.debug.print("[{s}:{d}]\tdt : {}\t\u{3B1} : {}\n", .{@src().file, @src().line, dt, alpha});
    _ = dt; _ = alpha;

    world.render();

    //var circle: draw.PolygonMesh = undefined;
    //draw.initPolygon(&circle, 5);
    //draw.solidPolygon(renderer, &circle, 250, 250, 50, counter, .{ .r = 0.9, .g = 0.23, .b = 0.45});

    return sdl.SDL_RenderPresent(renderer);
}