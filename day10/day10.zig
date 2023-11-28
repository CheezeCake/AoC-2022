const std = @import("std");

const Instruction = struct {
    const Operation = enum { Addx, Noop };

    op: Operation,
    value: ?i32,
};

const CPU = struct {
    x: i32,

    const Self = @This();

    fn init() Self {
        return Self{ .x = 1 };
    }

    fn execute(self: *Self, instr: Instruction) void {
        switch (instr.op) {
            Instruction.Operation.Addx => self.*.x += instr.value.?,
            Instruction.Operation.Noop => {},
        }
    }
};

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var instructions = std.ArrayList(Instruction).init(allocator);
    defer instructions.deinit();

    var buffer: [16]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        var it = std.mem.split(u8, line, " ");
        if (it.next()) |mnemonic| {
            if (std.mem.eql(u8, mnemonic, "addx")) {
                if (it.next()) |value| {
                    const v = try std.fmt.parseInt(i32, value, 10);
                    try instructions.append(Instruction{ .op = Instruction.Operation.Addx, .value = 0 });
                    try instructions.append(Instruction{ .op = Instruction.Operation.Addx, .value = v });
                } else {
                    return error.AddxMissingValue;
                }
            } else if (std.mem.eql(u8, mnemonic, "noop")) {
                try instructions.append(Instruction{ .op = Instruction.Operation.Noop, .value = null });
            } else {
                return error.UnknownInstruction;
            }
        }
    }

    var cpu = CPU.init();
    var CRT = [_][40]u8{[_]u8{'.'} ** 40} ** 6;

    var signalStrengthSum: usize = 0;
    var cycle: usize = 1;

    while (cycle < instructions.items.len) : (cycle += 1) {
        if (cycle >= 20 and (cycle - 20) % 40 == 0) {
            signalStrengthSum += cycle * @as(usize, @intCast(cpu.x));
        }

        const position = cycle - 1;
        const line = position / 40;
        const column = position % 40;
        if (cpu.x - 1 <= column and column <= cpu.x + 1) {
            CRT[line][column] = '#';
        }

        cpu.execute(instructions.items[cycle - 1]);
    }

    try stdout.print("part 1: {}\n", .{signalStrengthSum});

    try stdout.print("part 2:\n", .{});
    for (CRT) |line| {
        try stdout.print("{s}\n", .{line});
    }
}
