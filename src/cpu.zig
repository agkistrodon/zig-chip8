const std = @import("std");
const Bitmap = @import("bitmap.zig").Bitmap;
const Display = @import("display.zig").Display;

pub const CPU = struct {
    const Self = @This();

    memory: *[]u8,
    bitmap: *Bitmap,
    display: *Display,
    pc: u16,
    i: u16,
    dtimer: u8,
    stimer: u8,
    v: [16]u8,
    stack: [16]u16,
    stack_idx: u8,
    paused: bool,
    paused_x: u8,
    speed: u8,
    rng: std.Random.DefaultPrng,

    pub fn create(
        memory: *[]u8, // Pointer to device memory
        bitmap: *Bitmap,
        display: *Display,
        seed: u64,
    ) Self {
        return Self{
            .memory = memory,
            .bitmap = bitmap,
            .display = display,
            .pc = 0x200, // ROMs are loaded in at 0x200 so this is where the PC will be
            .i = 0,
            .dtimer = 0,
            .stimer = 0,
            .v = std.mem.zeroes([16]u8), // Create zero-initialized array,
            .stack = std.mem.zeroes([16]u16),
            .stack_idx = 0,
            .paused = false,
            .paused_x = 0, // For storing key press after un-pausing
            .speed = 10,
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    // Cycle through opcodes
    pub fn cycle(self: *Self) void {
        if (self.paused) {
            var i: u8 = 0;
            while (i < 16) : (i += 1) {
                if (self.display.keys[i]) {
                    self.paused = false;
                    self.v[self.paused_x] = i;
                }
            }
        }

        var i: u8 = 0;
        while (i < self.speed) : (i += 1) {
            // We aren't running instructions
            // if the emulator is paused
            if (!self.paused) {
                // CHIP-8 opcodes are two bytes long
                // .* is used to dereference pointers in Zig
                const opcode: u16 = (@as(u16, self.memory.*[self.pc]) << 8 | @as(u16, self.memory.*[self.pc + 1]));
                self.executeInstruction(opcode);
            }
        }

        if (!self.paused) {
            self.updateTimers();
        }

        self.playSound();
    }

    // Update timers
    fn updateTimers(self: *Self) void {
        if (self.dtimer > 0) self.dtimer -= 1;
        if (self.stimer > 0) self.stimer -= 1;
    }

    fn playSound(self: *Self) void {
        if (self.stimer > 0) {
            // TODO
        } else {
            // TODO
        }
    }

    // Push address to stack
    fn stackPush(self: *Self, address: u16) void {
        if (self.stack_idx > 15) return;

        self.stack[self.stack_idx] = address;
        self.stack_idx += 1;
    }

    // Pop address from stack
    fn stackPop(self: *Self) u16 {
        if (self.stack_idx == 0) return 0;

        const value = self.stack[self.stack_idx - 1];
        self.stack_idx -= 1;
        return value;
    }

    // Execute opcode
    fn executeInstruction(self: *Self, opcode: u16) void {
        self.pc += 2;

        const x = (opcode & 0x0F00) >> 8;
        const y = (opcode & 0x00F0) >> 4;

        switch (opcode & 0xF000) {
            0x0000 => {
                switch (opcode) {
                    0x00E0 => {
                        // CLS: clears the screen
                        self.bitmap.clear(0);
                    },
                    0x00EE => {
                        // RET: pop the last address off the stack, store in pc
                        self.pc = self.stackPop();
                    },
                    else => {},
                }
            },
            0x1000 => {
                // JMP: set pc to value stored in nnn
                self.pc = (opcode & 0xFFF);
            },
            0x2000 => {
                // CALL: Push current pc addreess to stack, jump to specified address
                self.stackPush(self.pc);
                self.pc = (opcode & 0xFFF);
            },
            0x3000 => {
                // SE Vx, byte: compare values and skip next instruction if equal
                if (self.v[x] == (opcode & 0xFF)) self.pc += 2;
            },
            0x4000 => {
                // SNE Vx, byte: compare values and skip next instruction if not equal
                if (self.v[x] != (opcode & 0xFF)) self.pc += 2;
            },
            0x5000 => {
                // SE Vx, Vy: compare values and skip next instruction if equal
                if (self.v[x] == self.v[y]) self.pc += 2;
            },
            0x6000 => {
                // LD Vx, byte: set the value at Vx to byte
                self.v[x] = @as(u8, @truncate(opcode & 0xFF));
            },
            0x7000 => {
                // ADD Vx, byte: add byte to Vx
                self.v[x] +%= @as(u8, @truncate(opcode & 0xFF));
            },
            0x8000 => {
                switch (opcode & 0xF) {
                    0x0 => {
                        // LD Vx, Vy
                        self.v[x] = self.v[y];
                    },
                    0x1 => {
                        // OR Vx, Vy
                        self.v[x] |= self.v[y];
                        self.v[0xF] = 0;
                    },
                    0x2 => {
                        // AND Vx, Vy
                        self.v[x] &= self.v[y];
                        self.v[0xF] = 0;
                    },
                    0x3 => {
                        // XOR Vx, Vy
                        self.v[x] ^= self.v[y];
                        self.v[0xF] = 0;
                    },
                    0x4 => {
                        // ADD Vx, Vy, set flag if overflow
                        const sum: u32 = (@as(u32, self.v[x]) + @as(u32, self.v[y]));
                        self.v[x] = @as(u8, @truncate(sum));
                        self.v[0xF] = 0;
                        if (sum > 0xFF) self.v[0xF] = 1;
                    },
                    0x5 => {
                        // SUB Vx, Vy, set flag if Vx > Vy
                        const vX = self.v[x];
                        const vY = self.v[y];
                        self.v[x] = vX -% vY;
                        self.v[0xF] = 0;
                        if (vX > vY) self.v[0xF] = 1;
                    },
                    0x6 => {
                        // SHR Vx, Vy: set Vx to Vy >> 1, set flag if LSB of Vy is 1
                        const vY = self.v[y];
                        self.v[x] = vY >> 1;
                        self.v[0xF] = 0;
                        if (vY & 0x01 != 0) self.v[0xF] = 1;
                    },
                    0x7 => {
                        // SUBN Vx, Vy: Set Vx to Vy - Vx, set flag if Vy > Vx
                        const vX = self.v[x];
                        const vY = self.v[y];
                        self.v[x] = vY -% vX;

                        self.v[0xF] = 0;
                        if (vY > vX) self.v[0xF] = 1;
                    },
                    0xE => {
                        // SHL Vx, Vy: set Vx to Vy << 1, set flag if MSB of Vy is 1
                        const vY = self.v[y];
                        self.v[x] = vY << 1;
                        self.v[0xF] = 0;
                        if (vY & 0x80 != 0) self.v[0xF] = 1;
                    },
                    else => {},
                }
            },
            0x9000 => {
                // SNE Vx, Vy: skip next instruction if Vx != Vy
                if (self.v[x] != self.v[y]) self.pc += 2;
            },
            0xA000 => {
                // LD i, addr: set value of register i to addr
                self.i = (opcode & 0xFFF);
            },
            0xB000 => {
                // JMP V0, addr: add addr to value of pc
                self.pc = (opcode & 0xFFF) + self.v[0];
            },
            0xC000 => {
                // RND Vx, byte: generate a random number 0-255, AND it with byte, store in Vx
                const num = self.rng.random().int(u8);
                self.v[x] = num & @as(u8, @truncate(opcode));
            },
            0xD000 => {
                // DRW Vx, Vy, nibble: display n-byte sprite
                const width: u16 = 8;
                const height = (opcode & 0xF);
                self.v[0xF] = 0;

                var row: u8 = 0;
                while (row < height) : (row += 1) {
                    const sprite = self.memory.*[self.i + row];
                    var col: u8 = 0;
                    while (col < width) : (col += 1) {
                        const px = self.v[x] % self.bitmap.width;
                        const py = self.v[y] % self.bitmap.height;

                        if (px + col >= self.bitmap.width) continue;
                        if (py + row >= self.bitmap.height) continue;

                        if (((sprite >> @intCast(7 - col)) & 1) == 1) {
                            if (self.bitmap.setPixel(px + col, py + row)) {
                                self.v[0xF] = 1;
                            }
                        }
                    }
                }
            },
            0xE000 => {
                switch (opcode & 0xFF) {
                    0x9E => {
                        // SKP Vx: skip next instruction if Vx is pressed
                        if (self.display.keys[self.v[x]]) self.pc += 2;
                    },
                    0xA1 => {
                        // SKNP Vx: skip next instruciton if Vx is not pressed
                        if (!self.display.keys[self.v[x]]) self.pc += 2;
                    },
                    else => {},
                }
            },
            0xF000 => {
                switch (opcode & 0xFF) {
                    0x07 => {
                        // LD Vx, DT: set Vx to value stored in the delay timer
                        self.v[x] = self.dtimer;
                    },
                    0x0A => {
                        // LD Vx, K: pause emulator until a key is pressed
                        self.paused = true;
                        self.paused_x = @as(u8, @truncate(x));
                    },
                    0x15 => {
                        // LD DT, Vx: Set delay timer to value in Vx
                        self.dtimer = self.v[x];
                    },
                    0x18 => {
                        // LD ST, Vx: Set sound timer to value in Vx
                        self.stimer = self.v[x];
                    },
                    0x1E => {
                        // ADD I, Vx: add Vx to I
                        self.i += self.v[x];
                    },
                    0x29 => {
                        // LD F, Vx - Add I, Vx: Set I to the location of the sprite stored in Vx
                        self.i = @as(u16, @intCast(self.v[x])) * 5;
                    },
                    0x33 => {
                        // LD B, Vx: grab the hundreds, tens, and ones digits in Vx and store in I+0, I+1, I+2
                        self.memory.*[self.i + 0] = (self.v[x] / 100) % 10;
                        self.memory.*[self.i + 1] = (self.v[x] / 10) % 10;
                        self.memory.*[self.i + 2] = self.v[x] % 10;
                    },
                    0x55 => {
                        // LD [I], Vx: Loop through V0 to VF and store their values consecutively starting at I
                        var ri: u16 = 0;
                        while (ri <= x) : (ri += 1) {
                            self.memory.*[self.i + ri] = self.v[ri];
                        }
                        self.i += ri;
                    },
                    0x65 => {
                        // LD Vx, [I]: Read values from memory starting at I and store in V0-VF
                        var ri: u16 = 0;
                        while (ri <= x) : (ri += 1) {
                            self.v[ri] = self.memory.*[self.i + ri];
                        }
                        self.i += ri;
                    },
                    else => {},
                }
            },
            else => {},
        }
    }
};
