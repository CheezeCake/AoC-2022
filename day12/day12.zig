const std = @import("std");

fn within_bounds(x: isize, y: isize, heightmap: [][]const u8) bool {
    return (y >= 0 and y < heightmap.len and x >= 0 and x < heightmap[@as(usize, @intCast(y))].len);
}

fn minSteps(fromX: usize, fromY: usize, toX: usize, toY: usize, heightmap: [][]const u8, visited: [][]bool, allocator: std.mem.Allocator) !?usize {
    const Q = std.TailQueue(struct { x: usize, y: usize, steps: usize });
    var q = Q{};
    defer {
        while (q.pop()) |node| {
            allocator.destroy(node);
        }
    }

    const first = try allocator.create(Q.Node);
    first.*.data = .{ .x = fromX, .y = fromY, .steps = 0 };
    q.append(first);

    while (q.popFirst()) |node| {
        defer allocator.destroy(node);
        const cur = node.data;

        if (visited[cur.y][cur.x]) {
            continue;
        }
        visited[cur.y][cur.x] = true; // visited

        if (cur.x == toX and cur.y == toY) {
            return cur.steps;
        }

        const directions = [_][2]isize{ [2]isize{ -1, 0 }, [2]isize{ 0, -1 }, [2]isize{ 1, 0 }, [2]isize{ 0, 1 } };
        for (directions) |dir| {
            const nx = @as(isize, @intCast(cur.x)) + dir[0];
            const ny = @as(isize, @intCast(cur.y)) + dir[1];
            if (within_bounds(nx, ny, heightmap)) {
                const x = @as(usize, @intCast(nx));
                const y = @as(usize, @intCast(ny));
                if (heightmap[y][x] <= heightmap[cur.y][cur.x] + 1) {
                    const next = try allocator.create(Q.Node);
                    next.*.data = .{ .x = x, .y = y, .steps = cur.steps + 1 };
                    q.append(next);
                }
            }
        }
    }

    return null;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var heightmap = std.ArrayList([]u8).init(allocator);
    defer {
        for (heightmap.items) |row| {
            allocator.free(row);
        }
        heightmap.deinit();
    }

    var startX: usize = 0;
    var startY: usize = 0;
    var targetX: usize = 0;
    var targetY: usize = 0;
    while (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
        try heightmap.append(line);
    }

    var visited = try allocator.alloc([]bool, heightmap.items.len);
    defer {
        for (visited) |row| {
            allocator.free(row);
        }
        allocator.free(visited);
    }

    for (heightmap.items, 0..) |row, y| {
        visited[y] = try allocator.alloc(bool, row.len);
        for (row, 0..) |height, x| {
            visited[y][x] = false;
            if (height == 'S') {
                startX = x;
                startY = y;
                heightmap.items[y][x] = 'a';
            } else if (height == 'E') {
                targetX = x;
                targetY = y;
                heightmap.items[y][x] = 'z';
            }
        }
    }

    const stepsFromStart = try minSteps(startX, startY, targetX, targetY, heightmap.items, visited, allocator);
    try stdout.print("part 1: {}\n", .{stepsFromStart.?});

    var min = stepsFromStart.?;
    for (heightmap.items, 0..) |row, y| {
        for (row, 0..) |height, x| {
            for (visited) |*vrow| {
                @memset(vrow.*, false);
            }
            if (height == 'a') {
                if (try minSteps(x, y, targetX, targetY, heightmap.items, visited, allocator)) |steps| {
                    min = @min(min, steps);
                }
            }
        }
    }
    try stdout.print("part 2: {}\n", .{min});
}
