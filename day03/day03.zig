const std = @import("std");
const assert = std.debug.assert;

fn priority(item: u8) error{UnknownItem}!u32 {
    return switch (item) {
        'a'...'z' => item - 'a' + 1,
        'A'...'Z' => item - 'A' + 27,
        else => error.UnknownItem,
    };
}

fn itemSet(rucksack: []u8, present: []bool) !void {
    for (rucksack) |item| {
        present[try priority(item)] = true;
    }
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var lines = std.ArrayList([]u8).init(allocator);
    defer {
        for (lines.items) |line| {
            allocator.free(line);
        }
        lines.deinit();
    }
    while (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
        try lines.append(line);
    }

    var prioritySum: u32 = 0;
    for (lines.items) |line| {
        const mid = line.len / 2;
        var present = [_]bool{false} ** 53;

        try itemSet(line[0..mid], &present);

        for (line[mid..]) |c| {
            const p = try priority(c);
            if (present[p]) {
                prioritySum += p;
                break;
            }
        }
    }
    try stdout.print("part 1: {}\n", .{prioritySum});

    assert(lines.items.len % 3 == 0);

    prioritySum = 0;
    var i: u32 = 0;
    while (i < lines.items.len) : (i += 3) {
        var present1 = [_]bool{false} ** 53;
        var present2 = [_]bool{false} ** 53;
        var present3 = [_]bool{false} ** 53;
        try itemSet(lines.items[i], &present1);
        try itemSet(lines.items[i + 1], &present2);
        try itemSet(lines.items[i + 2], &present3);

        for (present1, 0..) |_, p| {
            if (present1[p] and present2[p] and present3[p]) {
                prioritySum += @intCast(p);
                break;
            }
        }
    }
    try stdout.print("part 2: {}\n", .{prioritySum});
}
