const std = @import("std");

const Motion = struct {
    const Direction = enum { Left, Right, Up, Down };

    direction: Direction,
    n: usize,
};

const Point = struct {
    x: isize,
    y: isize,
};

fn follow(head: Point, tail: Point) !Point {
    const xDiff = head.x - tail.x;
    const yDiff = head.y - tail.y;
    if ((try std.math.absInt(xDiff)) > 1 or (try std.math.absInt(yDiff)) > 1) {
        return Point{
            .x = tail.x + std.math.clamp(xDiff, -1, 1),
            .y = tail.y + std.math.clamp(yDiff, -1, 1),
        };
    } else {
        return tail;
    }
}

fn simulate(motions: []const Motion, knots: []Point, allocator: std.mem.Allocator) !usize {
    var visited = std.AutoHashMap(Point, void).init(allocator);
    defer visited.deinit();

    try visited.put(knots[knots.len - 1], {});

    for (motions) |motion| {
        var i: usize = 0;
        while (i < motion.n) : (i += 1) {
            switch (motion.direction) {
                Motion.Direction.Left => knots[0].x -= 1,
                Motion.Direction.Right => knots[0].x += 1,
                Motion.Direction.Up => knots[0].y -= 1,
                Motion.Direction.Down => knots[0].y += 1,
            }

            var j: usize = 0;
            while (j + 1 < knots.len) : (j += 1) {
                knots[j + 1] = try follow(knots[j], knots[j + 1]);
            }
            try visited.put(knots[knots.len - 1], {});
        }
    }

    return visited.count();
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var motions = std.ArrayList(Motion).init(allocator);
    defer motions.deinit();

    var buffer: [16]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        const direction = line[0];
        const n = try std.fmt.parseInt(usize, line[2..], 10);

        try motions.append(Motion{ .direction = switch (direction) {
            'L' => Motion.Direction.Left,
            'U' => Motion.Direction.Up,
            'R' => Motion.Direction.Right,
            'D' => Motion.Direction.Down,
            else => return error.UnknownDirection,
        }, .n = n });
    }

    var knots = [_]Point{Point{ .x = 0, .y = 0 }} ** 10;
    try stdout.print("part 1: {}\n", .{try simulate(motions.items, knots[0..2], allocator)});

    knots[0] = Point{ .x = 0, .y = 0 };
    knots[1] = Point{ .x = 0, .y = 0 };
    try stdout.print("part 2: {}\n", .{try simulate(motions.items, &knots, allocator)});
}
