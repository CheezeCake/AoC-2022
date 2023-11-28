const std = @import("std");

fn parseSNAFU(s: []const u8) !i64 {
    var n: i64 = 0;

    for (s) |c| {
        const x: i64 = switch (c) {
            '2' => 2,
            '1' => 1,
            '0' => 0,
            '-' => -1,
            '=' => -2,
            else => return error.InvalidCharacter,
        };
        n = n * 5 + x;
    }

    return n;
}

fn toSNAFU(n: i64, allocator: std.mem.Allocator) ![]u8 {
    var s = std.ArrayList(u8).init(allocator);

    var x = n;
    var carry: i64 = 0;
    while (x > 0) {
        switch (@mod(x, 5) + carry) {
            0...2 => |d| {
                try s.append('0' + @as(u8, @intCast(d)));
                carry = 0;
            },
            3 => {
                try s.append('=');
                carry = 1;
            },
            4 => {
                try s.append('-');
                carry = 1;
            },
            5 => {
                try s.append('0');
                carry = 1;
            },
            else => unreachable,
        }

        x = @divTrunc(x, 5);
    }

    if (carry == 1) {
        try s.append('1');
    }

    std.mem.reverse(u8, s.items);

    return s.toOwnedSlice();
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sum: i64 = 0;

    var buffer: [32]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        sum += try parseSNAFU(line);
    }

    const SNAFU = try toSNAFU(sum, allocator);
    defer allocator.free(SNAFU);
    try stdout.print("part 1: {s}\n", .{SNAFU});
}
