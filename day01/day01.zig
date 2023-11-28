const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buffer: [16]u8 = undefined;
    var sum: u32 = 0;
    var first: u32 = 0;
    var second: u32 = 0;
    var third: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        if (line.len == 0) {
            if (sum >= first) {
                third = second;
                second = first;
                first = sum;
            } else if (sum >= second) {
                third = second;
                second = sum;
            } else if (sum >= third) {
                third = sum;
            }
            sum = 0;
        } else {
            sum += try std.fmt.parseInt(u32, line, 10);
        }
    }

    try stdout.print("part 1: {}\n", .{first});
    try stdout.print("part 2: {}\n", .{first + second + third});
}
