const std = @import("std");
const math = std.math;

const Value = union(enum) {
    integer: u32,
    list: std.ArrayList(Value),

    const Self = @This();

    fn isInteger(self: Self) bool {
        return switch (self) {
            .integer => true,
            else => false,
        };
    }

    fn integer2List(integer: u32, allocator: std.mem.Allocator) Value {
        var list = Value{ .list = std.ArrayList(Value).initCapacity(allocator, 1) catch unreachable };
        list.list.append(Value{ .integer = integer }) catch unreachable;

        return list;
    }

    fn order(context: void, left: Self, right: Self) math.Order {
        var buf: [@sizeOf(Value) * 8]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();

        const leftIsInt = left.isInteger();
        const rightIsInt = right.isInteger();

        if (leftIsInt and rightIsInt) {
            return math.order(left.integer, right.integer);
        } else if (leftIsInt) {
            const list = integer2List(left.integer, allocator);
            defer list.free();
            return order(context, list, right);
        } else if (rightIsInt) {
            const list = integer2List(right.integer, allocator);
            defer list.free();
            return order(context, left, list);
        } else {
            var i: usize = 0;
            const leftLen = left.list.items.len;
            const rightLen = right.list.items.len;
            const len = @min(leftLen, rightLen);
            while (i < len) : (i += 1) {
                switch (order(context, left.list.items[i], right.list.items[i])) {
                    .eq => {},
                    else => |o| return o,
                }
            }
            return math.order(leftLen, rightLen);
        }
    }

    fn lessThan(context: void, lhs: Self, rhs: Self) bool {
        return switch (order(context, lhs, rhs)) {
            .lt => true,
            else => false,
        };
    }

    fn free(self: Self) void {
        switch (self) {
            .integer => {},
            .list => |list| {
                for (list.items) |v| {
                    v.free();
                }
                list.deinit();
            },
        }
    }

    fn clone(self: Self, allocator: std.mem.Allocator) anyerror!Self {
        return switch (self) {
            .integer => |int| Value{ .integer = int },
            .list => |list| {
                var cloned = Value{ .list = try std.ArrayList(Value).initCapacity(allocator, list.items.len) };
                for (list.items) |value| {
                    try cloned.list.append(try value.clone(allocator));
                }
                return cloned;
            },
        };
    }
};

fn parsePacket(s: []const u8, allocator: std.mem.Allocator) !?Value {
    var stack = std.ArrayList(Value).init(allocator);
    defer stack.deinit();
    errdefer {
        for (stack.items) |value| {
            value.free();
        }
    }

    var current = Value{ .list = std.ArrayList(Value).init(allocator) };

    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '[') {
            try stack.append(current);
            current = Value{ .list = std.ArrayList(Value).init(allocator) };
            i += 1;
        } else if (s[i] == ']') {
            var parent = stack.pop();
            try parent.list.append(current);
            current = parent;
            i += 1;
        } else if (std.ascii.isDigit(s[i])) {
            var int = Value{ .integer = 0 };
            while (std.ascii.isDigit(s[i])) {
                int.integer = int.integer * 10 + s[i] - '0';
                i += 1;
            }
            try current.list.append(int);
        } else {
            i += 1;
        }
    }

    if (stack.items.len > 0 or current.list.items.len != 1) {
        return error.ParseError;
    }

    const value = current.list.pop();
    current.list.deinit();
    return value;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var packets = std.ArrayList(Value).init(allocator);
    defer {
        for (packets.items) |packet| {
            packet.free();
        }
        packets.deinit();
    }

    var index: usize = 1;
    var indexSum: usize = 0;

    var buffer: [1024]u8 = undefined;
    while (true) : (index += 1) {
        const leftStr = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        const left = try parsePacket(leftStr.?, allocator);
        try packets.append(left.?);

        const rightStr = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        const right = try parsePacket(rightStr.?, allocator);
        try packets.append(right.?);

        if (Value.lessThan({}, left.?, right.?)) {
            indexSum += index;
        }

        const separator = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        if (separator == null) {
            break;
        }
    }

    try stdout.print("part 1: {}\n", .{indexSum});

    const divider1 = (try parsePacket("[[2]]", allocator)).?;
    defer divider1.free();
    const divider2 = (try parsePacket("[[6]]", allocator)).?;
    defer divider2.free();
    try packets.append(try divider1.clone(allocator));
    try packets.append(try divider2.clone(allocator));

    std.sort.pdq(Value, packets.items, {}, Value.lessThan);

    const divider1Index = std.sort.binarySearch(Value, divider1, packets.items, {}, Value.order).?;
    const divider2Index = std.sort.binarySearch(Value, divider2, packets.items, {}, Value.order).?;
    try stdout.print("part 2: {}\n", .{(divider1Index + 1) * (divider2Index + 1)});
}
