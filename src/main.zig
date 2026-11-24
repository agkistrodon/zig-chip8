const std = @import("std");
const Device = @import("device.zig").Device;
const Display = @import("display.zig").Display;
const Bitmap = @import("bitmap.zig").Bitmap;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("MEMORY LEAK");
        }
    }

    var device = try Device.create(allocator);
    defer device.free();

    if (!device.loadROM(io, "roms/blitz.rom")) {
        std.debug.print("Failed to load CHIP-8 ROM\n", .{});
        return;
    }

    var bitmap = try Bitmap.create(allocator, 64, 32);
    defer bitmap.free();
    _ = bitmap.setPixel(5, 5);

    var display = try Display.create("CHIP-8", 800, 400, bitmap.width, bitmap.height);
    defer display.free();

    while (display.open) {
        display.input();
        display.draw(&bitmap);
    }
}
