const std = @import("std");

const ListNode = struct {
    prev: ?*ListNode = null,
    next: ?*ListNode = null,
    n: i64,

    const Self = @This();

    fn remove(self: *Self) void {
        self.*.prev.?.*.next = self.*.next;
        self.*.next.?.*.prev = self.*.prev;

        self.*.prev = null;
        self.*.next = null;
    }

    fn insertAfter(self: *Self, x: *Self) void {
        const next = self.next.?;
        self.*.next = x;
        x.*.prev = self;
        x.*.next = next;
        next.*.prev = x;
    }

    fn nthAfter(self: Self, n: usize) Self {
        var it = self;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            it = it.next.?.*;
        }
        return it;
    }
};

fn initCircularList(numbers: []ListNode) void {
    for (numbers, 0..) |*num, i| {
        if (i > 0) {
            const prev = &numbers[i - 1];
            prev.*.next = num;
            num.*.prev = prev;
        }
    }
    if (numbers.len > 0) {
        const first = &numbers[0];
        const last = &numbers[numbers.len - 1];
        first.*.prev = last;
        last.*.next = first;
    }
}

fn mix(numbers: []ListNode) void {
    for (numbers) |*num| {
        const n = std.math.absCast(num.n) % (numbers.len - 1);
        var prev = num.*.prev.?;
        num.remove();
        var i: usize = 0;
        while (i < n) : (i += 1) {
            if (num.n > 0) {
                prev = prev.*.next.?;
            } else {
                prev = prev.*.prev.?;
            }
        }
        prev.insertAfter(num);
    }
}

fn decrypt(numbers: []ListNode, mixCount: usize) !i64 {
    initCircularList(numbers);

    var i: usize = 0;
    while (i < mixCount) : (i += 1) {
        mix(numbers);
    }

    for (numbers) |num| {
        if (num.n == 0) {
            const a = num.nthAfter(1000 % numbers.len).n;
            const b = num.nthAfter(2000 % numbers.len).n;
            const c = num.nthAfter(3000 % numbers.len).n;

            return a + b + c;
        }
    }

    return error.NoZeroInNumbers;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var numbers = std.ArrayList(ListNode).init(allocator);
    defer numbers.deinit();

    var buffer: [16]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        const n = try std.fmt.parseInt(i64, line, 10);
        try numbers.append(ListNode{ .n = n });
    }

    try stdout.print("part 1: {}\n", .{try decrypt(numbers.items, 1)});

    const decryptionKey = 811589153;
    for (numbers.items) |*num| {
        num.*.n *= decryptionKey;
    }
    try stdout.print("part 2: {}\n", .{try decrypt(numbers.items, 10)});
}
