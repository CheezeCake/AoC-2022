const std = @import("std");

const Mineral = enum(u2) {
    ore,
    clay,
    obsidian,
    geode,

    fn getShift(self: Mineral) u6 {
        return @as(u6, @intFromEnum(self)) * 16;
    }
};

const Inventory = struct {
    val: u64 = 0,

    const Self = @This();

    fn new(ore: u64) Self {
        return Self{ .val = ore };
    }

    fn getMineral(self: Self, mineral: Mineral) u64 {
        return (self.val >> mineral.getShift()) & 0xffff;
    }

    fn addMineral(self: *Self, x: u64, mineral: Mineral) void {
        self.val += (x << mineral.getShift());
    }
};

const Blueprint = [4]Inventory;

fn getValue(x: u64, ore: u6) u64 {
    return (x >> (ore * 16)) & 0xffff;
}

fn addValue(x: u64, y: u64, ore: u6) u64 {
    return x + (y << (ore * 16));
}

fn buildRobot(cost: Inventory, ressources: Inventory) ?Inventory {
    var new = Inventory{};

    for (0..4) |mineral| {
        const mineralEnum = @as(Mineral, @enumFromInt(mineral));
        const mineralCost = cost.getMineral(mineralEnum);
        const mineralRes = ressources.getMineral(mineralEnum);
        if (mineralRes < mineralCost) {
            return null;
        } else {
            new.addMineral(mineralRes - mineralCost, mineralEnum);
        }
    }

    return new;
}

fn collect(robots: Inventory, ressources: Inventory) Inventory {
    var new = Inventory{};

    for (0..4) |mineral| {
        const mineralEnum = @as(Mineral, @enumFromInt(mineral));
        const mineralRobots = robots.getMineral(mineralEnum);
        const mineralRes = ressources.getMineral(mineralEnum);
        new.addMineral(mineralRes + mineralRobots, mineralEnum);
    }

    return new;
}

fn sum(n: usize) usize {
    return (n * (n + 1)) / 2;
}

fn dfs(bp: Blueprint, minutes: usize, robots: Inventory, ressources: Inventory, max: *usize) !void {
    var res = ressources;
    var rbts = robots;
    var min = minutes;
    var built = [_]bool{false} ** 4;

    while (min > 0) : (min -= 1) {
        max.* = @max(max.*, res.getMineral(Mineral.geode) + rbts.getMineral(Mineral.geode) * min);

        if (res.getMineral(Mineral.geode) + rbts.getMineral(Mineral.geode) * min + sum(min - 1) <= max.*) {
            break;
        }

        if (std.mem.allEqual(bool, &built, true)) {
            break;
        }

        for (bp, 0..) |cost, i| {
            if (built[i]) {
                continue;
            }
            if (buildRobot(cost, res)) |r| {
                built[i] = true;
                const collected = collect(rbts, r);
                var newRobots = rbts;
                newRobots.addMineral(1, @enumFromInt(i));
                try dfs(bp, min - 1, newRobots, collected, max);
            }
        }
        res = collect(rbts, res);
    }

    max.* = @max(max.*, ressources.getMineral(Mineral.geode));
}

fn parseRobotCost(str: []const u8) !Inventory {
    var cost = Inventory{};
    var it = std.mem.split(u8, str, " ");
    const stderr = std.io.getStdErr().writer();

    while (it.next()) |word| {
        const n = std.fmt.parseInt(usize, word, 10) catch continue;
        const ressource = it.next().?;
        if (std.mem.eql(u8, ressource, "ore")) {
            cost.addMineral(n, Mineral.ore);
        } else if (std.mem.eql(u8, ressource, "clay")) {
            cost.addMineral(n, Mineral.clay);
        } else if (std.mem.eql(u8, ressource, "obsidian")) {
            cost.addMineral(n, Mineral.obsidian);
        } else {
            try stderr.print("unknown ressource: '{s}'\n", .{ressource});
            return error.UnknownRessource;
        }
    }

    return cost;
}

fn parseBlueprint(str: []const u8) !Blueprint {
    const colon = std.mem.indexOfScalar(u8, str, ':').?;
    var it = std.mem.split(u8, str[colon + 2 ..], ".");
    var i: usize = 0;
    var blueprint = [_]Inventory{.{}} ** 4;

    while (it.next()) |robotCost| : (i += 1) {
        if (robotCost.len > 0) {
            blueprint[i] = try parseRobotCost(robotCost);
        }
    }

    return blueprint;
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var blueprints = std.ArrayList(Blueprint).init(allocator);
    defer blueprints.deinit();

    var buffer: [256]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        try blueprints.append(try parseBlueprint(line));
    }

    var s: usize = 0;
    for (blueprints.items, 0..) |bp, i| {
        const robots = Inventory.new(1);
        const ressources = Inventory{};
        var x: usize = 0;
        try dfs(bp, 24, robots, ressources, &x);

        s += x * (i + 1);
    }

    try stdout.print("part 1: {}\n", .{s});

    var p: usize = 1;
    for (blueprints.items[0..3]) |bp| {
        const robots = Inventory.new(1);
        const ressources = Inventory{};
        var x: usize = 0;
        try dfs(bp, 32, robots, ressources, &x);

        p *= x;
    }

    try stdout.print("part 2: {}\n", .{p});
}
