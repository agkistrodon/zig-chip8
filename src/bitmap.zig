const std = @import("std");

pub const Bitmap = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    width: u8,
    height: u8,
    pixels: []u1,

    // Create bitmap
    pub fn create(allocator: std.mem.Allocator, width: u8, height: u8) !Self {
        const pixels = try allocator.alloc(u1, @as(u16, width) * @as(u16, height));
        @memset(pixels, 0);

        return Self{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    // Free bitmap
    pub fn free(self: *Self) void {
        self.allocator.free(self.pixels);
    }

    // Clear bitmap to specified value
    pub fn clear(self: *Self, value: u1) void {
        @memset(self.pixels, value);
    }

    // Set pixel value at x, y
    pub fn setPixel(self: *Self, x: u8, y: u8) bool {
        if (x >= self.width or y >= self.height) return false;
        const index: usize = @as(usize, x) + @as(usize, y) * @as(usize, self.width);
        self.pixels[index] ^= 1;
        return self.pixels[index] == 0;
    }

    // Get pixel value at x, y
    pub fn getPixel(self: *Self, x: u8, y: u8) u1 {
        if (x >= self.width or y >= self.height) return 0;
        const index: usize = @as(usize, x) + @as(usize, y) * @as(usize, self.width);
        return self.pixels[index];
    }
};
