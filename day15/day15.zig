const std = @import("std");

const Point = struct {
    x: isize,
    y: isize,

    const Self = @This();

    fn manhattanDistance(self: Self, other: Point) !isize {
        return (try std.math.absInt(self.x - other.x)) + (try std.math.absInt(self.y - other.y));
    }
};

fn parseCoordinates(str: []const u8) !?Point {
    var eq = std.mem.indexOfScalar(u8, str, '=') orelse return null;
    const comma = std.mem.indexOfScalar(u8, str, ',').?;
    const x = try std.fmt.parseInt(isize, str[eq + 1 .. comma], 10);
    eq = std.mem.indexOfScalarPos(u8, str, comma, '=') orelse return null;
    const y = try std.fmt.parseInt(isize, str[eq + 1 ..], 10);
    return Point{ .x = x, .y = y };
}

const Interval = struct {
    start: isize,
    end: isize,

    fn lessThan(context: void, lhs: Interval, rhs: Interval) bool {
        _ = context;

        if (lhs.start == rhs.start) {
            return (lhs.end < rhs.end);
        } else {
            return (lhs.start < rhs.start);
        }
    }
};

fn mergeIntervals(intervals: []Interval, allocator: std.mem.Allocator) ![]Interval {
    var result = std.ArrayList(Interval).init(allocator);

    std.sort.pdq(Interval, intervals, {}, Interval.lessThan);

    var i: usize = 0;
    while (i < intervals.len) {
        const start = intervals[i].start;
        var end = intervals[i].end;
        var j = i + 1;
        while (j < intervals.len and intervals[j].start <= end) {
            end = @max(end, intervals[j].end);
            j += 1;
        }

        try result.append(.{ .start = start, .end = end });

        i = j;
    }

    return result.toOwnedSlice();
}

fn noBeaconIntervals(sensors: std.AutoHashMap(Point, isize), y: isize, allocator: std.mem.Allocator) ![]Interval {
    var intervals = std.ArrayList(Interval).init(allocator);
    defer intervals.deinit();

    var it = sensors.iterator();
    while (it.next()) |e| {
        const sensor = e.key_ptr.*;
        const distance = e.value_ptr.*;
        const dy = try std.math.absInt(sensor.y - y);

        if (dy <= distance) {
            const dx = distance - dy;
            try intervals.append(.{ .start = sensor.x - dx, .end = sensor.x + dx });
        }
    }

    return try mergeIntervals(intervals.items, allocator);
}

fn outsideSearchAreas(sensors: std.AutoHashMap(Point, isize), p: Point) !bool {
    var it = sensors.iterator();

    while (it.next()) |e| {
        const sensor = e.key_ptr.*;
        const distance = e.value_ptr.*;
        if ((try sensor.manhattanDistance(p)) <= distance) {
            return false;
        }
    }

    return true;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sensors = std.AutoHashMap(Point, isize).init(allocator);
    defer sensors.deinit();

    var buffer: [128]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':').?;
        const sensor = (try parseCoordinates(line[0..colon])).?;
        const beacon = (try parseCoordinates(line[colon + 1 ..])).?;

        try sensors.put(sensor, try sensor.manhattanDistance(beacon));
    }

    const intervals = try noBeaconIntervals(sensors, 2000000, allocator);
    defer allocator.free(intervals);
    var count: usize = 0;
    for (intervals) |interval| {
        count += @intCast(interval.end - interval.start);
    }
    try stdout.print("part 1: {}\n", .{count});

    var it = sensors.iterator();
    while (it.next()) |e| {
        const sensor = e.key_ptr.*;
        const radius = e.value_ptr.*;

        var dx: isize = 0;
        while (dx <= radius + 1) : (dx += 1) {
            const dy: isize = (radius + 1) - dx;
            const x = sensor.x;
            const y = sensor.y;
            const outsideEdges = [4]Point{
                .{ .x = x - dx, .y = y - dy },
                .{ .x = x - dx, .y = y + dy },
                .{ .x = x + dx, .y = y - dy },
                .{ .x = x + dx, .y = y + dy },
            };
            for (outsideEdges) |edge| {
                if (edge.x >= 0 and edge.x < 4000000 and edge.y >= 0 and edge.y < 4000000 and
                    (try outsideSearchAreas(sensors, edge)))
                {
                    try stdout.print("part 2: {}\n", .{edge.x * 4000000 + edge.y});
                    return;
                }
            }
        }
    }
}
