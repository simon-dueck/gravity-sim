const std = @import("std");

pub fn Stack(comptime T: type, capacity: u32) type {
    return struct {  
        const Self = @This();

        array: [capacity]T,
        size: u32,

        pub fn init(self: *Self) void { self.size = 0; }

        pub fn isEmpty(self: *Self) bool { return self.size == 0; }

        pub fn isFull(self: *Self) bool { return self.size == capacity; }

        pub fn peek(self: *Self) !T {
            if (self.isEmpty()) @panic("stack is empty");
            return self.array[self.size - 1];
        }

        pub fn pop(self: *Self) !T {
            if (self.isEmpty()) @panic("stack is empty");
            self.size -= 1;
            return self.array[self.size];
        }

        pub fn push(self: *Self, item: T) void {
            if (self.isFull()) @panic("stack is full");
            self.array[self.size] = item;
            self.size += 1;
        }

    };

}