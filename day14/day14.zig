const std = @import("std");

const Point = struct {
    x: isize,
    y: isize,
};

fn parsePoint(str: []const u8) !Point {
    if (std.mem.indexOfScalar(u8, str, ',')) |comma| {
        return Point{
            .x = try std.fmt.parseInt(isize, str[0..comma], 10),
            .y = try std.fmt.parseInt(isize, str[comma + 1 ..], 10),
        };
    } else {
        return error.InvalidPoint;
    }
}

fn sandRestingPlace(sandSource: Point, cave: *std.AutoHashMap(Point, u8), floor: isize, virtualFloor: bool) ?Point {
    var sand = sandSource;

    while (sand.y < floor) {
        var nextPos = Point{ .x = sand.x, .y = sand.y + 1 };
        const vFloor = (nextPos.y == floor and virtualFloor);

        if (cave.contains(nextPos) or vFloor) {
            nextPos.x = sand.x - 1;
            if (cave.contains(nextPos) or vFloor) {
                nextPos.x = sand.x + 1;
                if (cave.contains(nextPos) or vFloor) {
                    return sand;
                }
            }
        }

        sand = nextPos;
    }

    return null;
}

fn fallingSandSim(sandSource: Point, cave: *std.AutoHashMap(Point, u8), lowestRockY: isize) !usize {
    var units: usize = 0;

    while (true) : (units += 1) {
        if (sandRestingPlace(sandSource, cave, lowestRockY, false)) |sand| {
            try cave.put(sand, 'o');
        } else {
            return units;
        }
    }
}

fn fallingSandSimFloor(sandSource: Point, cave: *std.AutoHashMap(Point, u8), floor: isize) !usize {
    var units: usize = 0;

    while (!cave.contains(sandSource)) : (units += 1) {
        if (sandRestingPlace(sandSource, cave, floor, true)) |sand| {
            try cave.put(sand, 'o');
        } else {
            unreachable;
        }
    }

    return units;
}

fn getDirection(a: isize, b: isize) isize {
    return switch (std.math.order(a, b)) {
        .eq => 0,
        .lt => 1,
        .gt => -1,
    };
}

fn traceLine(from: Point, to: Point, cave: *std.AutoHashMap(Point, u8)) !void {
    const dir = Point{
        .x = getDirection(from.x, to.x),
        .y = getDirection(from.y, to.y),
    };
    var cur = from;

    while (cur.x != to.x or cur.y != to.y) {
        try cave.put(cur, '#');
        cur.x += dir.x;
        cur.y += dir.y;
    }
    try cave.put(cur, '#');
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cave = std.AutoHashMap(Point, u8).init(allocator);
    defer cave.deinit();

    var buffer: [512]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        var it = std.mem.split(u8, line, " -> ");
        var from = try parsePoint(it.next().?);
        while (it.next()) |toStr| {
            var to = try parsePoint(toStr);
            try traceLine(from, to, &cave);
            from = to;
        }
    }

    var lowestRockY: isize = 0;
    var it = cave.iterator();
    while (it.next()) |p| {
        lowestRockY = @max(lowestRockY, p.key_ptr.y);
    }

    var cave2 = try cave.clone();
    defer cave2.deinit();
    const sandSource = Point{ .x = 500, .y = 0 };

    try stdout.print("part 1: {}\n", .{try fallingSandSim(sandSource, &cave, lowestRockY)});
    try stdout.print("part 2: {}\n", .{try fallingSandSimFloor(sandSource, &cave2, lowestRockY + 2)});
}
