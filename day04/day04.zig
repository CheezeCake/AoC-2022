const std = @import("std");
const assert = std.debug.assert;

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var assignments = std.ArrayList([4]u32).init(allocator);
    defer assignments.deinit();

    var buffer: [1024]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        var ranges: [4]u32 = undefined;
        var it = std.mem.tokenize(u8, line, "-,");
        var i: u32 = 0;
        while (it.next()) |val| : (i += 1) {
            assert(i < 4);
            ranges[i] = try std.fmt.parseInt(u32, val, 10);
        }

        try assignments.append(ranges);
    }

    var fullOverlap: u32 = 0;
    var someOverlap: u32 = 0;
    for (assignments.items) |ranges| {
        const start1 = ranges[0];
        const end1 = ranges[1];
        const start2 = ranges[2];
        const end2 = ranges[3];
        if ((start1 <= start2 and end1 >= end2) or (start2 <= start1 and end2 >= end1)) {
            fullOverlap += 1;
            someOverlap += 1;
        } else if (end1 >= start2 and end2 >= start1) {
            someOverlap += 1;
        }
    }

    try stdout.print("part 1: {}\n", .{fullOverlap});
    try stdout.print("part 2: {}\n", .{someOverlap});
}
