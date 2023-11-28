const std = @import("std");

const Valve = struct {
    id: usize,
    flowRate: usize,
};

fn valveNameToId(name: [2]u8) usize {
    return @as(usize, name[0] - 'A') * 26 + (name[1] - 'A');
}

const InputError = error{InvalidInput};

fn parseValve(str: []const u8) !Valve {
    if (std.mem.indexOfScalar(u8, str, ' ')) |space| {
        if (std.mem.indexOfScalar(u8, str, '=')) |equal| {
            if (space + 2 < str.len and equal + 1 < str.len) {
                return Valve{ .id = valveNameToId([2]u8{ str[space + 1], str[space + 2] }), .flowRate = try std.fmt.parseInt(usize, str[equal + 1 ..], 10) };
            }
        }
    }

    return InputError.InvalidInput;
}

fn parseValveList(str: []const u8, dist: []usize) !void {
    if (str.len < 2) {
        return InputError.InvalidInput;
    }

    const comma = std.mem.indexOfScalar(u8, str, ',') orelse str.len;
    var it = std.mem.split(u8, str[comma - 2 ..], ", ");
    while (it.next()) |valveName| {
        const valveId = valveNameToId(valveName[0..2].*);
        dist[valveId] = 1;
    }
}

const maxValveId = 26 * 26 - 1;

fn distances(valves: []usize, dist: *[maxValveId][maxValveId]usize) void {
    // Floyd–Warshall
    for (valves) |k| {
        for (valves) |i| {
            for (valves) |j| {
                if (dist[i][k] < std.math.maxInt(usize) - dist[k][j]) {
                    dist[i][j] = @min(dist[i][j], dist[i][k] + dist[k][j]);
                }
            }
        }
    }
}

fn dfs(currentValve: usize, minutes: usize, valves: []usize, flowRates: *[maxValveId]usize, dist: [maxValveId][maxValveId]usize) usize {
    const flowRate = flowRates[currentValve];
    flowRates[currentValve] = 0;

    var maxReleased: usize = 0;

    for (valves) |nextValve| {
        if (nextValve != currentValve and flowRates[nextValve] > 0 and minutes >= dist[currentValve][nextValve] + 1) {
            maxReleased = @max(maxReleased, dfs(nextValve, minutes - dist[currentValve][nextValve] - 1, valves, flowRates, dist));
        }
    }

    flowRates[currentValve] = flowRate;

    return flowRate * minutes + maxReleased;
}

fn dfs2(currentValve: usize, minutes: usize, valves: []usize, flowRates: *[maxValveId]usize, dist: [maxValveId][maxValveId]usize) usize {
    const flowRate = flowRates[currentValve];
    flowRates[currentValve] = 0;

    var maxReleased: usize = 0;

    const elephantRelease = dfs(0, 26, valves, flowRates, dist);

    for (valves) |nextValve| {
        if (nextValve != currentValve and flowRates[nextValve] > 0 and minutes >= dist[currentValve][nextValve] + 1) {
            maxReleased = @max(maxReleased, dfs2(nextValve, minutes - dist[currentValve][nextValve] - 1, valves, flowRates, dist));
        }
    }

    flowRates[currentValve] = flowRate;

    return flowRate * minutes + @max(maxReleased, elephantRelease);
}

fn id2str(id: usize) [2]u8 {
    const x: u8 = @intCast(id / 26);
    const y: u8 = @intCast(id % 26);
    return .{ 'A' + x, 'A' + y };
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var ids: [maxValveId]usize = undefined;
    var idsCount: usize = 0;
    var flowRates: [maxValveId]usize = undefined;
    var dist = [_][maxValveId]usize{[_]usize{std.math.maxInt(usize)} ** maxValveId} ** maxValveId;

    var buffer: [128]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        if (std.mem.indexOfScalar(u8, line, ';')) |semicolon| {
            const valve = try parseValve(line[0..semicolon]);
            ids[idsCount] = valve.id;
            idsCount += 1;
            flowRates[valve.id] = valve.flowRate;
            try parseValveList(line[semicolon + 2 ..], &dist[valve.id]);
            dist[valve.id][valve.id] = 0;
        } else {
            return InputError.InvalidInput;
        }
    }

    const valves = ids[0..idsCount];
    distances(valves, &dist);

    try stdout.print("part 1: {}\n", .{dfs(0, 30, valves, &flowRates, dist)});
    try stdout.print("part 2: {}\n", .{dfs2(0, 26, valves, &flowRates, dist)});
}
