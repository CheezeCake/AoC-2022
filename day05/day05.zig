const std = @import("std");
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();

fn moveWithCrateMover9000(n: usize, from: *std.ArrayList(u8), to: *std.ArrayList(u8)) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        try to.append(from.pop());
    }
}

fn moveWithCrateMover9001(n: usize, from: *std.ArrayList(u8), to: *std.ArrayList(u8)) !void {
    try moveWithCrateMover9000(n, from, to);
    const len = to.items.len;
    std.mem.reverse(u8, to.items[len - n ..]);
}

fn printStackTops(stacks: [][2]std.ArrayList(u8), i: usize) !void {
    for (stacks) |stack| {
        try stdout.print("{c}", .{stack[i].items[stack[i].items.len - 1]});
    }
    try stdout.print("\n", .{});
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stacks = std.ArrayList([2]std.ArrayList(u8)).init(allocator);
    defer {
        for (stacks.items) |stack| {
            stack[0].deinit();
            stack[1].deinit();
        }
        stacks.deinit();
    }
    var buffer: [64]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        if (line.len == 0) {
            break;
        }
        var i: usize = 0;
        while (i * 4 + 1 < line.len) : (i += 1) {
            if (i >= stacks.items.len) {
                try stacks.append([2]std.ArrayList(u8){ std.ArrayList(u8).init(allocator), std.ArrayList(u8).init(allocator) });
            }
            const c = line[i * 4 + 1];
            if (c >= 'A' and c <= 'Z') {
                try stacks.items[i][0].append(c);
                try stacks.items[i][1].append(c);
            }
        }
    }
    for (stacks.items) |stack| {
        std.mem.reverse(u8, stack[0].items);
        std.mem.reverse(u8, stack[1].items);
    }

    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        var it = std.mem.tokenize(u8, line, " ");
        assert(std.mem.eql(u8, it.next().?, "move"));
        const n = try std.fmt.parseInt(usize, it.next().?, 10);
        assert(std.mem.eql(u8, it.next().?, "from"));
        const from = try std.fmt.parseInt(usize, it.next().?, 10);
        assert(from >= 1 and from <= stacks.items.len);
        assert(std.mem.eql(u8, it.next().?, "to"));
        const to = try std.fmt.parseInt(usize, it.next().?, 10);
        assert(to >= 1 and to <= stacks.items.len);
        assert(it.next() == null);

        try moveWithCrateMover9000(n, &stacks.items[from - 1][0], &stacks.items[to - 1][0]);
        try moveWithCrateMover9001(n, &stacks.items[from - 1][1], &stacks.items[to - 1][1]);
    }

    try stdout.print("part 1: ", .{});
    try printStackTops(stacks.items, 0);

    try stdout.print("part 2: ", .{});
    try printStackTops(stacks.items, 1);
}
