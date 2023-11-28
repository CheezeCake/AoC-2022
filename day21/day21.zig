const std = @import("std");

const Monkey = [4]u8;

const Operation = struct {
    lhs: Expression,
    operator: Operator,
    rhs: Expression,
    allocator: std.mem.Allocator,

    const Operator = enum {
        Add,
        Subtract,
        Multiply,
        Divide,

        fn new(c: u8) ?Operator {
            return switch (c) {
                '+' => .Add,
                '-' => .Subtract,
                '*' => .Multiply,
                '/' => .Divide,
                else => null,
            };
        }

        fn priority(self: Operator) usize {
            return switch (self) {
                .Add => 1,
                .Subtract => 1,
                .Multiply => 2,
                .Divide => 2,
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
        self.lhs.free();
        self.rhs.free();
        self.allocator.destroy(self);
    }

    fn evaluate(self: Self, variable: i64) i64 {
        const lhs = self.lhs.evaluate(variable);
        const rhs = self.rhs.evaluate(variable);
        return switch (self.operator) {
            .Add => lhs + rhs,
            .Subtract => lhs - rhs,
            .Multiply => lhs * rhs,
            .Divide => @divTrunc(lhs, rhs),
        };
    }

    fn parse(str: []const u8, allocator: std.mem.Allocator) !*Self {
        if (str.len != 11) {
            return error.InvalidOperation;
        }

        var lhs: Monkey = undefined;
        @memcpy(&lhs, str[0..4]);

        var rhs: Monkey = undefined;
        @memcpy(&rhs, str[7..11]);

        if (Self.Operator.new(str[5])) |op| {
            return try Self.create(allocator, Expression{ .variable = lhs }, op, Expression{ .variable = rhs });
        } else {
            return error.InvalidOperator;
        }
    }
};

const Expression = union(enum) {
    operation: *Operation,
    constant: i64,
    variable: Monkey,

    const Self = @This();

    fn createOperation(allocator: std.mem.Allocator, lhs: Expression, operator: Operation.Operator, rhs: Expression) !Expression {
        return Expression{ .operation = try Operation.create(allocator, lhs, operator, rhs) };
    }

    fn evaluate(self: Self, variable: i64) i64 {
        return switch (self) {
            .constant => |value| value,
            .operation => |operation| operation.evaluate(variable),
            .variable => variable,
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
                    .Subtract => try stdout.writeAll(" - "),
                    .Multiply => try stdout.writeAll(" * "),
                    .Divide => try stdout.writeAll(" / "),
                }
                try operation.rhs.print();
                try stdout.writeAll(")");
            },
            .variable => |v| try stdout.print("{s}", .{v}),
        }
    }
};

fn parseJobExpression(str: []const u8, allocator: std.mem.Allocator) !Expression {
    if (std.fmt.parseInt(i64, str, 10)) |n| {
        return Expression{ .constant = n };
    } else |err| switch (err) {
        error.InvalidCharacter => return Expression{ .operation = try Operation.parse(str, allocator) },
        else => return err,
    }
}

fn expandExpressionTree(e: Expression, monkeys: std.AutoHashMap(Monkey, Expression), allocator: std.mem.Allocator) !Expression {
    return switch (e) {
        .constant => e,
        .variable => |v| if (monkeys.get(v)) |ve| try expandExpressionTree(ve, monkeys, allocator) else e,
        .operation => |o| blk: {
            const lhs = try expandExpressionTree(o.lhs, monkeys, allocator);
            errdefer lhs.free();
            const rhs = try expandExpressionTree(o.rhs, monkeys, allocator);
            errdefer rhs.free();
            break :blk Expression{ .operation = try Operation.create(allocator, lhs, o.operator, rhs) };
        },
    };
}

fn hasVariable(e: Expression) bool {
    return switch (e) {
        .constant => false,
        .variable => true,
        .operation => |o| hasVariable(o.lhs) or hasVariable(o.rhs),
    };
}

fn pathToVariable(root: *Expression, path: *std.ArrayList(*Expression)) !bool {
    return switch (root.*) {
        .constant => false,
        .variable => blk: {
            try path.append(root);
            break :blk true;
        },
        .operation => |o| blk: {
            try path.append(root);
            if (try pathToVariable(&o.lhs, path) or try pathToVariable(&o.rhs, path)) {
                break :blk true;
            }
            _ = path.pop();
            break :blk false;
        },
    };
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var monkeys = std.AutoHashMap(Monkey, Expression).init(allocator);
    defer {
        var it = monkeys.iterator();
        while (it.next()) |e| {
            e.value_ptr.*.free();
        }
        monkeys.deinit();
    }

    var buffer: [32]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        var name: Monkey = undefined;
        @memcpy(&name, line.ptr);
        const job = try parseJobExpression(line[6..], allocator);
        try monkeys.put(name, job);
    }

    const human = [4]u8{ 'h', 'u', 'm', 'n' };
    const humanValue = monkeys.get(human).?.constant;
    _ = monkeys.remove(human);

    const rootName = [4]u8{ 'r', 'o', 'o', 't' };
    const root = try expandExpressionTree(monkeys.get(rootName).?, monkeys, allocator);
    defer root.free();
    try stdout.print("part 1: {}\n", .{root.evaluate(humanValue)});

    var path = std.ArrayList(*Expression).init(allocator);
    defer path.deinit();

    _ = try pathToVariable(&root.operation.lhs, &path);
    var eq = root.operation.rhs;

    for (path.items, 0..) |e, i| {
        switch (e.*) {
            .constant => unreachable,
            .variable => break,
            .operation => |o| {
                if (&o.lhs == path.items[i + 1]) {
                    eq = switch (o.operator) {
                        .Add => try Expression.createOperation(allocator, eq, Operation.Operator.Subtract, o.rhs),
                        .Subtract => try Expression.createOperation(allocator, eq, Operation.Operator.Add, o.rhs),
                        .Multiply => try Expression.createOperation(allocator, eq, Operation.Operator.Divide, o.rhs),
                        .Divide => try Expression.createOperation(allocator, eq, Operation.Operator.Multiply, o.rhs),
                    };
                } else {
                    eq = switch (o.operator) {
                        .Add => try Expression.createOperation(allocator, eq, Operation.Operator.Subtract, o.lhs),
                        .Subtract => try Expression.createOperation(allocator, o.lhs, Operation.Operator.Subtract, eq),
                        .Multiply => try Expression.createOperation(allocator, eq, Operation.Operator.Divide, o.lhs),
                        .Divide => try Expression.createOperation(allocator, o.lhs, Operation.Operator.Divide, eq),
                    };
                }
            },
        }
    }

    while (path.popOrNull()) |e| {
        switch (e.*) {
            .operation => |o| allocator.destroy(o),
            else => {},
        }
    }

    root.operation.lhs = Expression{ .constant = 0 };
    root.operation.rhs = eq;

    try stdout.print("part 2: {}\n", .{eq.evaluate(0)});
}
