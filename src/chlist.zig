const std = @import("std");
const Allocator = std.mem.Allocator;

const base_shift = 6;
const max_chunks = 32 - base_shift;

const Index = struct { chunk: u32, sub: u32 };

pub fn compound_index(index: u32) Index {
    const base_size: u32 = 1 << base_shift;
    const x: u32 = index / base_size + 1;

    const chunk: u5 = @intCast(32 - @clz(x) - 1);
    const sub: u32 = index - (base_size * ((@as(u32, 1) << chunk) - 1));

    return .{ .chunk = chunk, .sub = sub };
}

pub fn ChunkedList(comptime T: type) type {
    return struct {
        const Self = @This();

        chunks: [max_chunks]?[]T,
        count: u32,
        //index: Index,
        allocator: Allocator,

        pub fn init(allocator_: Allocator) Self {
            const self: Self = .{
                .chunks = [_]?[]T{null} ** max_chunks,
                .count = 0,
                //.index = compound_index(0),
                .allocator = allocator_,
            };

            //@memset(&self.chunks, null);

            return self;
        }

        pub fn deinit(self: *Self) void {
            for (self.chunks) |chunk| {
                self.allocator.free(chunk orelse continue);
            }
        }

        fn allocate_chunk(self: *Self, chunk_index: u32, chunk_size: u32) !void {
            if (self.chunks[chunk_index] != null)
                @panic("Chunk already allocated");

            self.chunks[chunk_index] = try self.allocator.alloc(T, chunk_size);
        }

        fn ensure_allocated(self: *Self, chunk: u32) !void {
            if (self.chunks[chunk] == null) {
                const size = (@as(u32, 1)) << @intCast(base_shift + chunk);
                self.chunks[chunk] = try self.allocator.alloc(T, size);
            }
        }

        pub fn at(self: *Self, index: u32) T {

            // check bounds
            if (index >= self.count) {
                @panic("Index is out of bounds");
            }

            // negative indexing !? am i cool like that? i have no idea, this might not work oops
            if (index < 0) {
                index = self.count + index;
            }

            const i = compound_index(index);

            return self.chunks[i.chunk].?[i.sub];
        }

        pub fn add(self: *Self, item: T) !void {
            const index = compound_index(self.count);
            try self.ensure_allocated(index.chunk);
            self.chunks[index.chunk].?[index.sub] = item;
            self.count = self.count + 1;
        }
    };
}

test "chunked list" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const l_type = ChunkedList(u32);
    var l = l_type.init(alloc);
    defer l.deinit();

    const len = 256;

    for (0..len) |i| {
        const n: u32 = @intCast(i);
        try l.add(n);
        //std.debug.print("array {any}\t", .{l.chunks});
    }

    for (0..(len)) |k| {
        std.debug.print("index {d}\t value {d}\t", .{ k, l.at(@intCast(k)) });
        std.debug.print("count {d}\t index {any}\n", .{ l.count, compound_index(@intCast(k)) });
        //std.debug.print("array {any}\t", .{l.chunks});

    }
}
