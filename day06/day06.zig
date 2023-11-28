const std = @import("std");
const assert = std.debug.assert;

fn noRepeatingChar(count: [26]usize) bool {
    for (count) |n| {
        if (n > 1) {
            return false;
        }
    }
    return true;
}

fn nonRepeatingCharSequenceIdx(data: []u8, seqLen: usize) ?usize {
    var count = [_]usize{0} ** 26;
    var i: usize = 0;
    return while (i < data.len) : (i += 1) {
        if (i >= seqLen and noRepeatingChar(count)) {
            break i;
        }
        if (i >= seqLen) {
            count[data[i - seqLen] - 'a'] -= 1;
        }
        if (i < data.len) {
            count[data[i] - 'a'] += 1;
        }
    } else null;
}

fn startOfPacketIndex(data: []u8) ?usize {
    return nonRepeatingCharSequenceIdx(data, 4);
}

fn startOfMessageIndex(data: []u8) ?usize {
    return nonRepeatingCharSequenceIdx(data, 14);
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buffer: [4096]u8 = undefined;
    const input = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')).?;

    try stdout.print("part 1: {}\n", .{startOfPacketIndex(input).?});
    try stdout.print("part 2: {}\n", .{startOfMessageIndex(input).?});
}
