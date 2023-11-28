const std = @import("std");

const Point = struct {
    x: isize = 0,
    y: isize = 0,
    z: isize = 0,
};

fn parsePoint(str: []const u8) !Point {
    var it = std.mem.split(u8, str, ",");
    const x = it.next() orelse return error.ParseError;
    const y = it.next() orelse return error.ParseError;
    const z = it.next() orelse return error.ParseError;
    return Point{ .x = try std.fmt.parseInt(isize, x, 10), .y = try std.fmt.parseInt(isize, y, 10), .z = try std.fmt.parseInt(isize, z, 10) };
}

fn sidesShowing(cubes: std.AutoHashMap(Point, void)) usize {
    var count: usize = 0;
    var it = cubes.iterator();

    while (it.next()) |entry| {
        const directions = [_]Point{
            .{ .x = -1 },
            .{ .x = 1 },
            .{ .y = -1 },
            .{ .y = 1 },
            .{ .z = -1 },
            .{ .z = 1 },
        };
        const cube = entry.key_ptr;

        for (directions) |dir| {
            const adj = Point{
                .x = cube.x + dir.x,
                .y = cube.y + dir.y,
                .z = cube.z + dir.z,
            };

            if (!cubes.contains(adj)) {
                count += 1;
            }
        }
    }

    return count;
}

fn dfs(cube: Point, cubes: std.AutoHashMap(Point, void), minCorner: Point, maxCorner: Point, visited: *std.AutoHashMap(Point, void)) !usize {
    if (cube.x < minCorner.x or cube.x > maxCorner.x or
        cube.y < minCorner.y or cube.y > maxCorner.y or
        cube.z < minCorner.z or cube.z > maxCorner.z or
        visited.contains(cube))
    {
        return 0;
    }
    if (cubes.contains(cube)) {
        return 1;
    }

    try visited.put(cube, {});

    const directions = [_]Point{
        .{ .x = -1 },
        .{ .x = 1 },
        .{ .y = -1 },
        .{ .y = 1 },
        .{ .z = -1 },
        .{ .z = 1 },
    };
    var count: usize = 0;
    for (directions) |dir| {
        const adj = Point{
            .x = cube.x + dir.x,
            .y = cube.y + dir.y,
            .z = cube.z + dir.z,
        };

        count += try dfs(adj, cubes, minCorner, maxCorner, visited);
    }

    return count;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cubes = std.AutoHashMap(Point, void).init(allocator);
    defer cubes.deinit();
    var minCorner = Point{
        .x = std.math.maxInt(isize),
        .y = std.math.maxInt(isize),
        .z = std.math.maxInt(isize),
    };
    var maxCorner = Point{
        .x = std.math.minInt(isize),
        .y = std.math.minInt(isize),
        .z = std.math.minInt(isize),
    };

    var buffer: [64]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        const p = try parsePoint(line);

        minCorner.x = @min(minCorner.x, p.x - 1);
        minCorner.y = @min(minCorner.y, p.y - 1);
        minCorner.z = @min(minCorner.z, p.z - 1);

        maxCorner.x = @max(maxCorner.x, p.x + 1);
        maxCorner.y = @max(maxCorner.y, p.y + 1);
        maxCorner.z = @max(maxCorner.z, p.z + 1);

        try cubes.put(p, {});
    }

    const showing = sidesShowing(cubes);
    try stdout.print("part 1: {}\n", .{showing});

    var visited = std.AutoHashMap(Point, void).init(allocator);
    defer visited.deinit();
    const n = try dfs(minCorner, cubes, minCorner, maxCorner, &visited);
    try stdout.print("part 2: {}\n", .{n});
}
