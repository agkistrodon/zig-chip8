const std = @import("std");
const Display = @import("display.zig");

pub fn main() !void {
    var display = try Display.create("CHIP-8", 800, 400);
    defer display.free();

    while (display.open) {
        display.input();
    }
}
