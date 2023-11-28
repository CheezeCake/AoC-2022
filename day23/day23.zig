const std = @import("std");

const Point = struct {
    x: isize,
    y: isize,
};

const Direction = struct {
    const NW = Point{ .x = -1, .y = -1 };
    const N = Point{ .x = 0, .y = -1 };
    const NE = Point{ .x = 1, .y = -1 };

    const SW = Point{ .x = -1, .y = 1 };
    const S = Point{ .x = 0, .y = 1 };
    const SE = Point{ .x = 1, .y = 1 };

    const W = Point{ .x = -1, .y = 0 };
    const E = Point{ .x = 1, .y = 0 };
};

const Grove = struct {
    elves: std.AutoHashMap(Point, void),
    allocator: std.mem.Allocator,
    considerationIdx: usize = 0,

    const DirectionConsideration = struct {
        direction: Point,
        check: [3]Point,
    };

    const considerations = [4]DirectionConsideration{
        .{
            .direction = Direction.N,
            .check = .{
                Direction.NW,
                Direction.N,
                Direction.NE,
            },
        },
        .{
            .direction = Direction.S,
            .check = .{
                Direction.SW,
                Direction.S,
                Direction.SE,
            },
        },
        .{
            .direction = Direction.W,
            .check = .{
                Direction.NW,
                Direction.W,
                Direction.SW,
            },
        },
        .{
            .direction = Direction.E,
            .check = .{
                Direction.NE,
                Direction.E,
                Direction.SE,
            },
        },
    };

    const Self = @This();

    fn noOneAround(self: Self, p: Point) bool {
        const directions = [8]Point{ Direction.NW, Direction.N, Direction.NE, Direction.E, Direction.SE, Direction.S, Direction.SW, Direction.W };
        for (directions) |direction| {
            const adj = Point{ .x = p.x + direction.x, .y = p.y + direction.y };
            if (self.elves.contains(adj)) {
                return false;
            }
        }

        return true;
    }

    fn consider(self: Self, p: Point, consideration: DirectionConsideration) bool {
        for (consideration.check) |direction| {
            const adj = Point{ .x = p.x + direction.x, .y = p.y + direction.y };
            if (self.elves.contains(adj)) {
                return false;
            }
        }
        return true;
    }

    fn round(self: *Self) !bool {
        var tmp = std.AutoHashMap(Point, void).init(self.allocator);
        var movement: bool = false;

        var it = self.elves.iterator();
        while (it.next()) |e| {
            const elf = e.key_ptr.*;

            if (self.noOneAround(elf)) {
                try tmp.put(elf, {});
            } else {
                for (0..4) |offset| {
                    const consideration = Self.considerations[(self.considerationIdx + offset) % 4];
                    if (self.consider(elf, consideration)) {
                        const dest = .{ .x = elf.x + consideration.direction.x, .y = elf.y + consideration.direction.y };
                        if (tmp.contains(dest)) {
                            _ = tmp.remove(dest);
                            try tmp.put(.{ .x = dest.x + consideration.direction.x, .y = dest.y + consideration.direction.y }, {});
                            try tmp.put(elf, {});
                        } else {
                            try tmp.put(dest, {});
                            movement = true;
                        }

                        break;
                    }
                } else {
                    try tmp.put(elf, {});
                }
            }
        }

        self.elves.deinit();
        self.elves = tmp;

        self.considerationIdx += 1;

        return movement;
    }

    fn areaSize(self: Self) usize {
        var minX: isize = std.math.maxInt(isize);
        var maxX: isize = std.math.minInt(isize);
        var minY: isize = std.math.maxInt(isize);
        var maxY: isize = std.math.minInt(isize);

        var it = self.elves.iterator();

        while (it.next()) |e| {
            const elf = e.key_ptr.*;
            minX = @min(minX, elf.x);
            maxX = @max(maxX, elf.x);
            minY = @min(minY, elf.y);
            maxY = @max(maxY, elf.y);
        }

        return @intCast((maxX - minX + 1) * (maxY - minY + 1));
    }

    fn emptyGround(self: Self) usize {
        return self.areaSize() - self.elves.count();
    }
};

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = std.AutoHashMap(Point, void).init(allocator);
    var y: isize = 0;

    var buffer: [128]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| : (y += 1) {
        for (line, 0..) |c, x| {
            if (c == '#') {
                try map.put(.{ .x = @intCast(x), .y = y }, {});
            }
        }
    }

    var grove = Grove{ .elves = map, .allocator = allocator };
    defer grove.elves.deinit();

    for (0..10) |_| {
        _ = try grove.round();
    }
    try stdout.print("part 1: {}\n", .{grove.emptyGround()});

    var r: usize = 11;
    while (try grove.round()) : (r += 1) {}
    try stdout.print("part 2: {}\n", .{r});
}
