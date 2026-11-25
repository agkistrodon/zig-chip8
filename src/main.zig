const std = @import("std");
const c = @import("c");
const Device = @import("device.zig").Device;
const Display = @import("display.zig").Display;
const Bitmap = @import("bitmap.zig").Bitmap;
const CPU = @import("cpu.zig").CPU;

const rom = "roms/blitz.rom";

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

    if (!device.loadROM(io, rom)) {
        std.debug.print("Failed to load CHIP-8 ROM\n", .{});
        return;
    }

    var bitmap = try Bitmap.create(allocator, 64, 32);
    defer bitmap.free();

    var display = try Display.create("CHIP-8", 800, 400, bitmap.width, bitmap.height);
    defer display.free();

    var cpu = CPU.create(&device.memory, &bitmap, &display, c.SDL_GetTicks());

    const fps: u32 = 60;
    const fpsInterval: u32 = 1000 / fps;
    var previousTime = c.SDL_GetTicks();

    while (display.open) {
        display.input();

        const currentTime = c.SDL_GetTicks();
        if (currentTime -% previousTime >= fpsInterval) {
            previousTime = currentTime;
            cpu.cycle();
            display.draw(&bitmap);
        }

        c.SDL_Delay(1);
    }
}
