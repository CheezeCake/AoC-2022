const std = @import("std");

const Point = struct {
    x: isize,
    y: isize,
};

const RockDispenser = struct {
    n: usize,

    const Rock = []const []const u8;
    const Rocks = [_]Rock{
        &[_][]const u8{"####"},
        &[_][]const u8{
            ".#.",
            "###",
            ".#.",
        },
        &[_][]const u8{
            "..#",
            "..#",
            "###",
        },
        &[_][]const u8{
            "#",
            "#",
            "#",
            "#",
        },
        &[_][]const u8{
            "##",
            "##",
        },
    };

    const Self = @This();

    fn init() Self {
        return Self{ .n = 0 };
    }

    fn next(self: *Self) usize {
        const index = self.n % Rocks.len;
        self.n += 1;
        return index;
    }

    fn revert(self: *Self) void {
        self.n -= 1;
    }
};

const GasJetDispenser = struct {
    pattern: []const u8,
    index: usize,

    const GasJet = enum {
        Left,
        Right,

        fn direction(self: GasJet) Point {
            return switch (self) {
                .Left => .{ .x = -1, .y = 0 },
                .Right => .{ .x = 1, .y = 0 },
            };
        }
    };

    const Self = @This();

    fn init(pattern: []const u8) Self {
        return Self{ .pattern = pattern, .index = 0 };
    }

    fn next(self: *Self) !GasJet {
        const ret = self.index;
        self.index = (self.index + 1) % self.pattern.len;
        return switch (self.pattern[ret]) {
            '<' => GasJet.Left,
            '>' => GasJet.Right,
            else => error.InvalidGasJetDirection,
        };
    }

    fn revert(self: *Self) void {
        self.index = switch (self.index) {
            0 => self.pattern.len - 1,
            else => self.index - 1,
        };
    }
};

fn moveRock(rock: RockDispenser.Rock, pos: Point, delta: Point, chamber: std.AutoHashMap(Point, void)) Point {
    const newPos = Point{ .x = pos.x + delta.x, .y = pos.y + delta.y };

    for (rock, 0..) |row, dy| {
        for (row, 0..) |e, dx| {
            if (e == '#') {
                const piecePos = Point{ .x = newPos.x + @as(isize, @intCast(dx)), .y = newPos.y - @as(isize, @intCast(dy)) };
                if (piecePos.x < 0 or piecePos.x >= 7 or piecePos.y < 0 or chamber.contains(piecePos)) {
                    return pos;
                }
            }
        }
    }

    return newPos;
}

fn makeRockFall(rock: RockDispenser.Rock, gasJets: *GasJetDispenser, chamber: std.AutoHashMap(Point, void), height: usize) !Point {
    var pos = Point{ .x = 2, .y = @as(isize, @intCast(height)) - 1 + 3 + @as(isize, @intCast(rock.len)) };

    while (true) {
        const jet = try gasJets.next();
        const posAfterGasJet = moveRock(rock, pos, jet.direction(), chamber);
        const posAfterFall = moveRock(rock, posAfterGasJet, .{ .x = 0, .y = -1 }, chamber);

        if (posAfterFall.y == posAfterGasJet.y) {
            return posAfterGasJet;
        }

        pos = posAfterFall;
    }
}

fn updateChamber(cave: *std.AutoHashMap(Point, void), rock: RockDispenser.Rock, pos: Point) !void {
    for (rock, 0..) |row, dy| {
        for (row, 0..) |e, dx| {
            if (e == '#') {
                const piecePos = Point{ .x = pos.x + @as(isize, @intCast(dx)), .y = pos.y - @as(isize, @intCast(dy)) };
                try cave.put(piecePos, {});
            }
        }
    }
}

fn simulate(n: usize, jetPattern: []const u8, allocator: std.mem.Allocator) !usize {
    var rocks = RockDispenser.init();
    var gasJets = GasJetDispenser.init(jetPattern);

    var chamber = std.AutoHashMap(Point, void).init(allocator);
    defer chamber.deinit();

    var seen = std.AutoHashMap(struct { rockIndex: usize, jetIndex: usize }, struct { nrRocks: usize, height: usize }).init(allocator);
    defer seen.deinit();

    var height: usize = 0;
    var ans: usize = 0;
    var nrRocksLeft: usize = 0;

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const rockIndex = rocks.next();
        const rock = RockDispenser.Rocks[rockIndex];

        if (i > gasJets.pattern.len * RockDispenser.Rocks.len) {
            const jetIndex = gasJets.index;
            const k = .{ .rockIndex = rockIndex, .jetIndex = jetIndex };
            if (seen.get(k)) |v| {
                const cycleLen = i - v.nrRocks;
                const cyclesLeft = (n - i) / cycleLen;
                const cycleHeight = height - v.height;

                nrRocksLeft = (n - i) % cycleLen;
                ans = cycleHeight * cyclesLeft;
                rocks.revert();
                break;
            } else {
                try seen.put(k, .{ .nrRocks = i, .height = height });
            }
        }

        const pos = try makeRockFall(rock, &gasJets, chamber, height);
        try updateChamber(&chamber, rock, pos);
        height = @max(height, @as(usize, @intCast(pos.y)) + 1);
    }

    i = 0;
    while (i < nrRocksLeft) : (i += 1) {
        const rockIndex = rocks.next();
        const rock = RockDispenser.Rocks[rockIndex];

        const pos = try makeRockFall(rock, &gasJets, chamber, height);
        try updateChamber(&chamber, rock, pos);
        height = @max(height, @as(usize, @intCast(pos.y)) + 1);
    }

    return ans + height;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer: [0x4000]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |jetPattern| {
        try stdout.print("part 1: {}\n", .{try simulate(2022, jetPattern, allocator)});
        try stdout.print("part 2: {}\n", .{try simulate(1000000000000, jetPattern, allocator)});
    } else {
        return error.InputReadError;
    }
}
