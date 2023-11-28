const std = @import("std");

const Point = struct {
    x: isize,
    y: isize,
};

const Terrain = union(enum) {
    wall,
    ground,
    blizards: u4,

    const Blizard = enum(u4) {
        up = 1 << 0,
        down = 1 << 1,
        left = 1 << 2,
        right = 1 << 3,

        fn nextPos(self: Blizard, pos: Point) Point {
            return switch (self) {
                .up => .{ .x = pos.x, .y = pos.y - 1 },
                .down => .{ .x = pos.x, .y = pos.y + 1 },
                .left => .{ .x = pos.x - 1, .y = pos.y },
                .right => .{ .x = pos.x + 1, .y = pos.y },
            };
        }

        fn getChar(self: Blizard) u8 {
            return switch (self) {
                .up => '^',
                .down => 'v',
                .left => '<',
                .right => '>',
            };
        }
    };

    const Self = @This();

    fn fromChar(c: u8) !Self {
        return switch (c) {
            '#' => .wall,
            '.' => .ground,
            '^' => .{ .blizards = @intFromEnum(Blizard.up) },
            'v' => .{ .blizards = @intFromEnum(Blizard.down) },
            '<' => .{ .blizards = @intFromEnum(Blizard.left) },
            '>' => .{ .blizards = @intFromEnum(Blizard.right) },
            else => error.InvalidChar,
        };
    }
};

const Map = struct {
    map: []Terrain,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    fn fromStrMap(strMap: [][]const u8, allocator: std.mem.Allocator) !Self {
        const height = strMap.len;
        const width = strMap[0].len;
        const map = try allocator.alloc(Terrain, height * width);

        for (strMap, 0..) |row, y| {
            for (row, 0..) |terrainChar, x| {
                map[y * width + x] = try Terrain.fromChar(terrainChar);
            }
        }

        return Self{
            .map = map,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.map);
    }

    fn withinBounds(self: Self, p: Point) bool {
        return (p.y >= 0 and @as(usize, @intCast(p.y)) < self.height and p.x >= 0 and @as(usize, @intCast(p.x)) < self.width);
    }

    fn get(self: Self, pos: Point) ?Terrain {
        if (self.withinBounds(pos)) {
            const x = @as(usize, @intCast(pos.x));
            const y = @as(usize, @intCast(pos.y));
            return self.map[y * self.width + x];
        } else {
            return null;
        }
    }

    fn blizardNextPosition(self: Self, blizard: Terrain.Blizard, blizardPos: Point) ?Point {
        if (self.withinBounds(blizardPos)) {
            const nextPos = blizard.nextPos(blizardPos);
            if (self.get(nextPos)) |nextPosTerrain| {
                switch (nextPosTerrain) {
                    .wall => {
                        if (nextPos.x == 0) {
                            return .{ .x = @intCast(self.width - 2), .y = nextPos.y };
                        } else if (nextPos.x == self.width - 1) {
                            return .{ .x = 1, .y = nextPos.y };
                        } else if (nextPos.y == 0) {
                            return .{ .x = nextPos.x, .y = @intCast(self.height - 2) };
                        } else if (nextPos.y == self.height - 1) {
                            return .{ .x = nextPos.x, .y = 1 };
                        } else {
                            unreachable;
                        }
                    },
                    else => return nextPos,
                }
            }
        }

        return null;
    }

    fn nextMinute(self: *Self) !void {
        const newMap = try self.allocator.alloc(Terrain, self.height * self.width);
        @memset(newMap, .ground);

        for (self.map, 0..) |terrain, i| {
            switch (terrain) {
                .wall => newMap[i] = .wall,
                .blizards => |b| {
                    const blizards = [4]Terrain.Blizard{ Terrain.Blizard.up, Terrain.Blizard.down, Terrain.Blizard.left, Terrain.Blizard.right };

                    for (blizards) |blizard| {
                        if (b & @intFromEnum(blizard) != 0) {
                            const p = Point{ .x = @intCast(i % self.width), .y = @intCast(i / self.width) };
                            const dest = self.blizardNextPosition(blizard, p).?;
                            const destIdx = @as(usize, @intCast(dest.y)) * self.width + @as(usize, @intCast(dest.x));
                            newMap[destIdx] = switch (newMap[destIdx]) {
                                .blizards => |bs| .{ .blizards = bs | @intFromEnum(blizard) },
                                else => .{ .blizards = @intFromEnum(blizard) },
                            };
                        }
                    }
                },
                else => {},
            }
        }

        const oldMap = self.map;
        defer self.allocator.free(oldMap);
        self.map = newMap;
    }

    fn print(self: Self, minute: usize) !void {
        const stdout = std.io.getStdOut().writer();

        try stdout.print("Minute {}:\n", .{minute});

        for (self.map, 0..) |terrain, i| {
            if (i > 0 and i % self.width == 0) {
                try stdout.writeAll("\n");
            }
            switch (terrain) {
                .wall => try stdout.writeAll("#"),
                .ground => try stdout.writeAll("."),
                .blizards => |b| {
                    const cnt = bitsSet(b);
                    if (cnt == 1) {
                        const blizard = @as(Terrain.Blizard, @enumFromInt(b));
                        try stdout.print("{c}", .{blizard.getChar()});
                    } else {
                        try stdout.print("{}", .{bitsSet(b)});
                    }
                },
            }
        }
        try stdout.writeAll("\n\n");
    }
};

fn bitsSet(b: u4) usize {
    var cnt: usize = 0;
    if (b & 1 != 0) {
        cnt += 1;
    }
    if (b & 2 != 0) {
        cnt += 1;
    }
    if (b & 4 != 0) {
        cnt += 1;
    }
    if (b & 8 != 0) {
        cnt += 1;
    }

    return cnt;
}

fn solve(start: Point, goal: Point, map: *Map, allocator: std.mem.Allocator) !?usize {
    var positions = std.AutoHashMap(Point, void).init(allocator);
    defer positions.deinit();
    try positions.put(start, {});

    var minute: usize = 0;

    while (true) : (minute += 1) {
        var nextPositions = std.AutoHashMap(Point, void).init(allocator);

        var it = positions.iterator();
        while (it.next()) |e| {
            const pos = e.key_ptr.*;

            if (map.get(pos)) |mapAtPos| {
                if (mapAtPos != Terrain.ground) {
                    continue;
                }
                if (pos.x == goal.x and pos.y == goal.y) {
                    nextPositions.deinit();
                    return minute;
                }

                // wait
                try nextPositions.put(pos, {});

                // move
                const directions = [4]Point{
                    .{ .x = 0, .y = -1 },
                    .{ .x = 0, .y = 1 },
                    .{ .x = -1, .y = 0 },
                    .{ .x = 1, .y = 0 },
                };
                for (directions) |dir| {
                    const nextPos = Point{ .x = pos.x + dir.x, .y = pos.y + dir.y };
                    try nextPositions.put(nextPos, {});
                }
            }
        }

        try map.nextMinute();

        var oldPositions = positions;
        defer oldPositions.deinit();
        positions = nextPositions;
    }

    return null;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var strMap = std.ArrayList([]const u8).init(allocator);
    defer {
        for (strMap.items) |row| {
            allocator.free(row);
        }
        strMap.deinit();
    }
    while (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 128)) |row| {
        try strMap.append(row);
    }

    var map = try Map.fromStrMap(strMap.items, allocator);
    defer map.deinit();

    const start = Point{ .x = 1, .y = 0 };
    const goal = Point{ .x = @as(isize, @intCast(map.width)) - 2, .y = @as(isize, @intCast(map.height)) - 1 };

    const minutesToGoal = (try solve(start, goal, &map, allocator)).?;
    try stdout.print("part 1: {}\n", .{minutesToGoal});

    const minutesBackToStart = (try solve(goal, start, &map, allocator)).?;
    const minutesBackToGoal = (try solve(start, goal, &map, allocator)).?;
    try stdout.print("part 2: {}\n", .{minutesToGoal + minutesBackToStart + minutesBackToGoal});
}
