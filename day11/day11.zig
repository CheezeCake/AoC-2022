const std = @import("std");

const Operation = struct {
    lhs: Expression,
    operator: Operator,
    rhs: Expression,
    allocator: std.mem.Allocator,

    const Operator = enum {
        Add,
        Multiply,
        Divide,
        Mod,

        fn new(c: u8) ?Operator {
            return switch (c) {
                '+' => .Add,
                '*' => .Multiply,
                '/' => .Divide,
                '%' => .Mod,
                else => null,
            };
        }

        fn priority(self: Operator) usize {
            return switch (self) {
                .Add => 1,
                .Multiply => 2,
                .Divide => 2,
                .Mod => 2,
            };
        }
    };

    const Self = @This();

    fn create(allocator: std.mem.Allocator, lhs: Expression, operator: Operator, rhs: Expression) !*Operation {
        var self = try allocator.create(Self);
        self.* = Self{
            .lhs = lhs,
            .operator = operator,
            .rhs = rhs,
            .allocator = allocator,
        };

        return self;
    }

    fn destroy(self: *Self) void {
        self.allocator.destroy(self);
    }

    fn evaluate(self: Self, variable: u64) u64 {
        const lhs = self.lhs.evaluate(variable);
        const rhs = self.rhs.evaluate(variable);
        return switch (self.operator) {
            .Add => lhs + rhs,
            .Multiply => lhs * rhs,
            .Divide => lhs / rhs,
            .Mod => lhs % rhs,
        };
    }
};

const Expression = union(enum) {
    operation: *Operation,
    constant: u64,
    variable: void,

    const Self = @This();

    fn evaluate(self: Self, variable: u64) u64 {
        return switch (self) {
            .constant => |value| value,
            .operation => |operation| operation.evaluate(variable),
            .variable => variable,
        };
    }

    fn clone(self: Self, allocator: std.mem.Allocator) !Expression {
        return switch (self) {
            .operation => |operation| .{ .operation = try Operation.create(allocator, operation.lhs, operation.operator, operation.rhs) },
            else => self,
        };
    }

    fn free(self: Self) void {
        switch (self) {
            .operation => |operation| operation.destroy(),
            else => {},
        }
    }

    fn print(self: Self) anyerror!void {
        const stdout = std.io.getStdOut().writer();
        switch (self) {
            .constant => |value| try stdout.print("{}", .{value}),
            .operation => |operation| {
                try stdout.writeAll("(");
                try operation.lhs.print();
                switch (operation.operator) {
                    .Add => try stdout.writeAll(" + "),
                    .Multiply => try stdout.writeAll(" * "),
                    .Divide => try stdout.writeAll(" / "),
                }
                try operation.rhs.print();
                try stdout.writeAll(")");
            },
            .variable => try stdout.writeAll("{var}"),
        }
    }
};

const Monkey = struct {
    items: std.TailQueue(u64),
    operation: Expression,
    divisionTest: u64,
    ok: usize,
    nOk: usize,

    allocator: std.mem.Allocator,

    const Self = @This();

    fn clone(self: Self, allocator: std.mem.Allocator) !Monkey {
        var cloned = Monkey{
            .items = undefined,
            .operation = try self.operation.clone(allocator),
            .divisionTest = self.divisionTest,
            .ok = self.ok,
            .nOk = self.nOk,
            .allocator = allocator,
        };

        const L = std.TailQueue(u64);
        var clonedItems = L{};

        var it = self.items.first;
        while (it) |node| : (it = node.next) {
            var clonedNode = try allocator.create(L.Node);
            clonedNode.data = node.data;
            clonedItems.append(clonedNode);
        }

        cloned.items = clonedItems;

        return cloned;
    }

    fn free(self: Self) void {
        var it = self.items.first;
        while (it) |node| {
            it = node.next;
            self.allocator.destroy(node);
        }

        self.operation.free();
    }
};

fn parseItems(str: []const u8, allocator: std.mem.Allocator) !std.TailQueue(u64) {
    const L = std.TailQueue(u64);
    var items = L{};

    var it = std.mem.split(u8, str, ", ");
    while (it.next()) |item| {
        var node = try allocator.create(L.Node);
        node.* = .{ .data = try std.fmt.parseInt(u64, item, 10) };
        items.append(node);
    }

    return items;
}

fn processOperator(exprs: *std.ArrayList(Expression), op: Operation.Operator, allocator: std.mem.Allocator) !void {
    const rhs = exprs.pop();
    const lhs = exprs.pop();
    const operation = try Operation.create(allocator, lhs, op, rhs);
    try exprs.append(.{ .operation = operation });
}

fn parseOperation(str: []const u8, allocator: std.mem.Allocator) !Expression {
    const equal = std.mem.indexOfScalar(u8, str, '=') orelse return error.InvalidOperation;
    var i = equal + 2;

    var exprs = std.ArrayList(Expression).init(allocator);
    defer exprs.deinit();
    var ops = std.ArrayList(Operation.Operator).init(allocator);
    defer ops.deinit();
    errdefer {
        while (exprs.popOrNull()) |expr| {
            expr.free();
        }
    }

    while (i < str.len) {
        if (str[i] == ' ') {
            i += 1;
        } else if (Operation.Operator.new(str[i])) |op| {
            while (ops.items.len > 0 and ops.items[ops.items.len - 1].priority() >= op.priority()) {
                try processOperator(&exprs, ops.pop(), allocator);
            }

            i += 1;

            try ops.append(op);
        } else if (std.ascii.isAlphabetic(str[i])) {
            var j = i + 1;
            while (j < str.len and std.ascii.isAlphabetic(str[j])) : (j += 1) {}
            if (!std.mem.eql(u8, str[i..j], "old")) {
                return error.InvalidVariable;
            }
            try exprs.append(.{ .variable = {} });

            i = j;
        } else if (std.ascii.isDigit(str[i])) {
            var n: u64 = 0;
            while (i < str.len and std.ascii.isDigit(str[i])) : (i += 1) {
                n = n * 10 + str[i] - '0';
            }
            try exprs.append(.{ .constant = n });
        } else {
            return error.InvalidExpression;
        }
    }

    while (ops.popOrNull()) |op| {
        try processOperator(&exprs, op, allocator);
    }

    if (exprs.items.len != 1) {
        return error.InvalidExpression;
    }

    return exprs.pop();
}

fn getLastInteger(str: []const u8) !u64 {
    const lastSpace = std.mem.lastIndexOfScalar(u8, str, ' ') orelse return error.InvalidDescriptionLine;
    return try std.fmt.parseInt(u64, str[lastSpace + 1 ..], 10);
}

fn lineValue(str: []const u8) ![]const u8 {
    const colon = std.mem.indexOfScalar(u8, str, ':') orelse return error.InvalidDescriptionLine;
    return str[colon + 2 ..];
}

fn parseMonkeys(allocator: std.mem.Allocator) ![]Monkey {
    var monkeys = std.ArrayList(Monkey).init(allocator);
    errdefer {
        for (monkeys.items) |monkey| {
            monkey.free();
        }
        monkeys.deinit();
    }

    const stdin = std.io.getStdIn().reader();

    var buffer: [128]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |_| {
        var description = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')).?;
        const items = try parseItems(try lineValue(description), allocator);

        description = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')).?;
        const operation = try parseOperation(try lineValue(description), allocator);

        description = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')).?;
        const divisionTest = try getLastInteger(description);

        description = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')).?;
        const ok = try getLastInteger(description);

        description = (try stdin.readUntilDelimiterOrEof(&buffer, '\n')).?;
        const nOk = try getLastInteger(description);

        var monkey = Monkey{
            .items = items,
            .operation = operation,
            .divisionTest = divisionTest,
            .ok = ok,
            .nOk = nOk,
            .allocator = allocator,
        };

        try monkeys.append(monkey);

        _ = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
    }

    return monkeys.toOwnedSlice();
}

fn run(monkeys: []Monkey, rounds: usize, op: *Operation, inspectionCount: []usize) !void {
    var round: usize = 1;

    while (round <= rounds) : (round += 1) {
        for (monkeys, 0..) |*monkey, i| {
            while (monkey.items.popFirst()) |node| {
                op.lhs = monkey.operation;
                node.data = op.evaluate(node.data);

                if (node.data % monkey.divisionTest == 0) {
                    monkeys[monkey.ok].items.append(node);
                } else {
                    monkeys[monkey.nOk].items.append(node);
                }
                inspectionCount[i] += 1;
            }
        }
    }
}

fn monkeyBusiness(inspectionCount: []usize) usize {
    var first: usize = 0;
    var second: usize = 0;
    for (inspectionCount) |count| {
        if (count >= first) {
            second = first;
            first = count;
        } else if (count > second) {
            second = count;
        }
    }

    return first * second;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var monkeys = try parseMonkeys(allocator);
    defer {
        for (monkeys) |monkey| {
            monkey.free();
        }
        allocator.free(monkeys);
    }
    var clonedMonkeys = std.ArrayList(Monkey).init(allocator);
    defer {
        for (clonedMonkeys.items) |monkey| {
            monkey.free();
        }
        clonedMonkeys.deinit();
    }
    for (monkeys) |monkey| {
        try clonedMonkeys.append(try monkey.clone(allocator));
    }

    var inspectionCount = std.ArrayList(usize).init(allocator);
    defer inspectionCount.deinit();
    try inspectionCount.appendNTimes(0, monkeys.len);

    var divByThree = Operation{
        .allocator = undefined,
        .lhs = undefined,
        .operator = Operation.Operator.Divide,
        .rhs = .{ .constant = 3 },
    };
    try run(monkeys, 20, &divByThree, inspectionCount.items);
    try stdout.print("part 1: {}\n", .{monkeyBusiness(inspectionCount.items)});

    var supermod: u64 = 1;
    for (monkeys) |monkey| {
        supermod *= monkey.divisionTest;
    }
    var modSupermod = Operation{
        .allocator = undefined,
        .lhs = undefined,
        .operator = Operation.Operator.Mod,
        .rhs = .{ .constant = supermod },
    };
    @memset(inspectionCount.items, 0);
    try run(clonedMonkeys.items, 10000, &modSupermod, inspectionCount.items);
    try stdout.print("part 2: {}\n", .{monkeyBusiness(inspectionCount.items)});
}
