const std = @import("std");

const Point = struct {
    x: isize = 0,
    y: isize = 0,
};

const Direction = enum {
    up,
    down,
    left,
    right,

    const Self = @This();

    fn oposite(self: Self) Self {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }

    fn turn(self: Self, clockwise: bool) Direction {
        if (clockwise) {
            return switch (self) {
                .up => .right,
                .down => .left,
                .left => .up,
                .right => .down,
            };
        } else {
            return switch (self) {
                .up => .left,
                .down => .right,
                .left => .down,
                .right => .up,
            };
        }
    }

    fn applyOrientation(self: Self, orientation: Direction) Direction {
        return switch (self) {
            .up => switch (orientation) {
                .up => .up,
                .down => .down,
                .left => .right,
                .right => .left,
            },
            .down => switch (orientation) {
                .up => .down,
                .down => .up,
                .left => .left,
                .right => .right,
            },
            .left => switch (orientation) {
                .up => .left,
                .down => .right,
                .left => .up,
                .right => .down,
            },
            .right => switch (orientation) {
                .up => .right,
                .down => .left,
                .left => .down,
                .right => .up,
            },
        };
    }

    fn rotate(self: Self, orientation: Direction) Direction {
        return switch (orientation) {
            .up => self,
            .down => self.turn(true).turn(true),
            .left => self.turn(false),
            .right => self.turn(true),
        };
    }
};

fn withinBounds(pos: Point, map: [][]const u8) bool {
    const x = pos.x;
    const y = pos.y;
    return y >= 0 and @as(isize, @intCast(y)) < map.len and x >= 0 and x < map[@intCast(y)].len;
}

const State = struct {
    pos: Point,
    dir: Direction,

    fn password(self: State) usize {
        const row = @as(usize, @intCast(self.pos.y)) + 1;
        const column = @as(usize, @intCast(self.pos.x)) + 1;
        const facing: usize = switch (self.dir) {
            .right => 0,
            .down => 1,
            .left => 2,
            .up => 3,
        };

        return 1000 * row + 4 * column + facing;
    }
};

const MapWalker = struct {
    pos: Point,
    dir: Direction,
    map: [][]const u8,

    const Self = @This();

    fn goForward(self: *Self) bool {
        var nextPos: Point = switch (self.dir) {
            .up => .{ .x = self.pos.x, .y = self.pos.y - 1 },
            .down => .{ .x = self.pos.x, .y = self.pos.y + 1 },
            .left => .{ .x = self.pos.x - 1, .y = self.pos.y },
            .right => .{ .x = self.pos.x + 1, .y = self.pos.y },
        };

        if (withinBounds(nextPos, self.map)) {
            const nextTile = self.map[@as(usize, @intCast(nextPos.y))][@as(usize, @intCast(nextPos.x))];
            if (nextTile == '.') {
                self.pos = nextPos;
                return true;
            } else if (nextTile == '#') {
                return false;
            } else {
                return self.wrapAround();
            }
        } else {
            return self.wrapAround();
        }

        return false;
    }

    fn wrapAround(self: *Self) bool {
        const prevPos = self.pos;
        const prevDir = self.dir;

        self.dir = self.dir.oposite();
        var pos = self.pos;

        while (true) {
            const nextPos: Point = switch (self.dir) {
                .up => .{ .x = pos.x, .y = pos.y - 1 },
                .down => .{ .x = pos.x, .y = pos.y + 1 },
                .left => .{ .x = pos.x - 1, .y = pos.y },
                .right => .{ .x = pos.x + 1, .y = pos.y },
            };
            if (!withinBounds(nextPos, self.map)) {
                break;
            }
            const nextTile = self.map[@as(usize, @intCast(nextPos.y))][@as(usize, @intCast(nextPos.x))];
            if (nextTile == ' ') {
                break;
            }

            pos = nextPos;
        }

        const tile = self.map[@as(usize, @intCast(pos.y))][@as(usize, @intCast(pos.x))];
        self.dir = prevDir;
        if (tile == '.') {
            self.pos = pos;
            return true;
        } else {
            self.pos = prevPos;
            return false;
        }
    }

    fn turn(self: *Self, clockwise: bool) void {
        self.dir = self.dir.turn(clockwise);
    }

    fn state(self: Self) State {
        return .{ .pos = self.pos, .dir = self.dir };
    }
};

const CubeWalker = struct {
    face: FaceType,
    offset: Point,
    dir: Direction,
    cube: [6]Face,
    map: [][]const u8,

    const Self = @This();

    const CubeState = struct {};

    fn posFromFaceOffset(facePos: Point, offset: Point) Point {
        return .{ .x = facePos.x + offset.x, .y = facePos.y + offset.y };
    }

    fn rotatePos(pos: Point, dir: Direction) Point {
        return switch (dir) {
            .up => pos,
            .down => rotatePos(rotatePos(pos, .right), .right),
            .left => .{ .x = pos.y, .y = FaceSize - pos.x - 1 },
            .right => .{ .x = FaceSize - pos.y - 1, .y = pos.x },
        };
    }

    fn goForward(self: *Self) bool {
        var nextOffset: Point = switch (self.dir) {
            .up => .{ .x = self.offset.x, .y = self.offset.y - 1 },
            .down => .{ .x = self.offset.x, .y = self.offset.y + 1 },
            .left => .{ .x = self.offset.x - 1, .y = self.offset.y },
            .right => .{ .x = self.offset.x + 1, .y = self.offset.y },
        };

        if (nextOffset.y >= 0 and nextOffset.y < FaceSize and nextOffset.x >= 0 and nextOffset.x < FaceSize) {
            const nextPos = posFromFaceOffset(self.cube[@intFromEnum(self.face)].pos, nextOffset);
            const nextTile = self.map[@as(usize, @intCast(nextPos.y))][@as(usize, @intCast(nextPos.x))];
            if (nextTile == '.') {
                self.offset = nextOffset;
                return true;
            } else if (nextTile == '#') {
                return false;
            } else {
                unreachable;
            }
        } else {
            const faceIdx = @intFromEnum(self.face);
            const dirIdx = @intFromEnum(self.dir);
            const nextFace = self.cube[faceIdx].neighbours[dirIdx].face;
            const nextFaceOrientation = self.cube[faceIdx].neighbours[dirIdx].orientation;

            const nextFaceIdx = @intFromEnum(nextFace);
            const nextFaceMapOrientation = self.cube[nextFaceIdx].orientation;
            var nfo = nextFaceOrientation;
            var nextDir = self.dir;
            nextOffset = self.offset;

            while (nfo != nextFaceMapOrientation) {
                nfo = nfo.turn(true);
                nextDir = nextDir.turn(true);

                const x = nextOffset.x;
                const y = nextOffset.y;
                nextOffset = .{ .x = FaceSize - y - 1, .y = x };
            }

            switch (nextDir) {
                .up => nextOffset.y = FaceSize - 1,
                .down => nextOffset.y = 0,
                .left => nextOffset.x = FaceSize - 1,
                .right => nextOffset.x = 0,
            }

            const nextPos = posFromFaceOffset(self.cube[@intFromEnum(nextFace)].pos, nextOffset);
            const nextTile = self.map[@as(usize, @intCast(nextPos.y))][@as(usize, @intCast(nextPos.x))];
            if (nextTile == '.') {
                self.face = nextFace;
                self.offset = nextOffset;
                self.dir = nextDir;
                return true;
            } else if (nextTile == '#') {
                return false;
            } else {
                unreachable;
            }
        }
    }

    fn faceDistance(face1: Point, face2: Point) usize {
        const dx: usize = @intCast(std.math.absInt(face1.x - face2.x) catch 0);
        const dy: usize = @intCast(std.math.absInt(face1.y - face2.y) catch 0);
        return (dx / FaceSize) + (dy / FaceSize);
    }

    fn turn(self: *Self, clockwise: bool) void {
        self.dir = self.dir.turn(clockwise);
    }

    fn state(self: Self) State {
        const facePos = self.cube[@intFromEnum(self.face)].pos;
        const pos = posFromFaceOffset(facePos, self.offset);
        return .{ .pos = pos, .dir = self.dir };
    }
};

fn walkPath(path: []const PathInstruction, walker: anytype) void {
    for (path) |inst| {
        switch (inst) {
            .steps => |n| {
                var i: usize = 0;
                while (i < n and walker.goForward()) : (i += 1) {}
            },
            .turn => |t| switch (t) {
                .left => walker.turn(false),
                .right => walker.turn(true),
            },
        }
    }
}

const FaceSize = 50;
const FaceType = enum { front, back, top, bottom, left, right };
const Face = struct {
    pos: Point,
    orientation: Direction,
    neighbours: [4]struct { face: FaceType, orientation: Direction },
};

fn isFace(pos: Point, map: [][]const u8) bool {
    return withinBounds(pos, map) and map[@as(usize, @intCast(pos.y))][@as(usize, @intCast(pos.x))] != ' ';
}

fn buildCube(face: FaceType, orientation: Direction, pos: Point, map: [][]const u8, cube: *[6]Face, visited: *[6]bool) !void {
    const faceIdx = @intFromEnum(face);

    if (!isFace(pos, map) or visited[faceIdx]) {
        return;
    }

    cube[faceIdx].pos = pos;
    cube[faceIdx].orientation = orientation;
    visited[faceIdx] = true;

    for ([4]Direction{ .up, .down, .left, .right }) |direction| {
        const nextPos: Point = switch (direction) {
            .up => .{ .x = pos.x, .y = pos.y - FaceSize },
            .down => .{ .x = pos.x, .y = pos.y + FaceSize },
            .left => .{ .x = pos.x - FaceSize, .y = pos.y },
            .right => .{ .x = pos.x + FaceSize, .y = pos.y },
        };
        const nextDirection = direction.applyOrientation(orientation);
        const next = switch (face) {
            .front => switch (nextDirection) {
                .up => .{ FaceType.top, Direction.up },
                .down => .{ FaceType.bottom, Direction.up },
                .left => .{ FaceType.left, Direction.up },
                .right => .{ FaceType.right, Direction.up },
            },
            .back => switch (nextDirection) {
                .up => .{ FaceType.top, Direction.down },
                .down => .{ FaceType.bottom, Direction.down },
                .left => .{ FaceType.right, Direction.up },
                .right => .{ FaceType.left, Direction.up },
            },
            .top => switch (nextDirection) {
                .up => .{ FaceType.back, Direction.down },
                .down => .{ FaceType.front, Direction.up },
                .left => .{ FaceType.left, Direction.right },
                .right => .{ FaceType.right, Direction.left },
            },
            .bottom => switch (nextDirection) {
                .up => .{ FaceType.front, Direction.up },
                .down => .{ FaceType.back, Direction.down },
                .left => .{ FaceType.left, Direction.left },
                .right => .{ FaceType.right, Direction.right },
            },
            .left => switch (nextDirection) {
                .up => .{ FaceType.top, Direction.left },
                .down => .{ FaceType.bottom, Direction.right },
                .left => .{ FaceType.back, Direction.up },
                .right => .{ FaceType.front, Direction.up },
            },
            .right => switch (nextDirection) {
                .up => .{ FaceType.top, Direction.right },
                .down => .{ FaceType.bottom, Direction.left },
                .left => .{ FaceType.front, Direction.up },
                .right => .{ FaceType.back, Direction.up },
            },
        };
        const nextFace = next[0];
        const nextFaceOrientation = next[1].rotate(orientation);

        cube[faceIdx].neighbours[@intFromEnum(direction)] = .{ .face = nextFace, .orientation = nextFaceOrientation };
        try buildCube(nextFace, nextFaceOrientation, nextPos, map, cube, visited);
    }
}

fn startingPosition(map: [][]const u8) ?Point {
    const x = std.mem.indexOfScalar(u8, map[0], '.') orelse return null;
    return Point{ .y = 0, .x = @as(isize, @intCast(x)) };
}

const PathInstruction = union(enum) {
    steps: usize,
    turn: enum { left, right },
};

fn parsePath(str: []const u8, allocator: std.mem.Allocator) ![]PathInstruction {
    var path = std.ArrayList(PathInstruction).init(allocator);

    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        if (str[i] == 'L') {
            try path.append(.{ .turn = .left });
        } else if (str[i] == 'R') {
            try path.append(.{ .turn = .right });
        } else if (std.ascii.isDigit(str[i])) {
            var steps: usize = 0;
            while (i < str.len and std.ascii.isDigit(str[i])) : (i += 1) {
                steps = steps * 10 + str[i] - '0';
            }
            i -= 1;
            try path.append(.{ .steps = steps });
        } else {
            return error.InvalidCharacter;
        }
    }

    return path.toOwnedSlice();
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = std.ArrayList([]const u8).init(allocator);
    defer {
        for (map.items) |row| {
            allocator.free(row);
        }
        map.deinit();
    }

    while (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 50 * 6)) |row| {
        if (row.len == 0) {
            allocator.free(row);
            break;
        } else {
            try map.append(row);
        }
    }

    var buf: [0x2000]u8 = undefined;
    const pathStr = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse return error.UnexpectedEndOfInput;
    const path = try parsePath(pathStr, allocator);
    defer allocator.free(path);

    const start = startingPosition(map.items).?;

    var mw = MapWalker{ .pos = start, .dir = Direction.right, .map = map.items };
    walkPath(path, &mw);
    try stdout.print("part 1: {}\n", .{mw.state().password()});

    var cube: [6]Face = undefined;
    var visited = [_]bool{false} ** 6;
    try buildCube(FaceType.front, Direction.up, start, map.items, &cube, &visited);

    var cw = CubeWalker{ .offset = .{ .x = 0, .y = 0 }, .dir = Direction.right, .cube = cube, .face = .front, .map = map.items };
    walkPath(path, &cw);
    try stdout.print("part 2: {}\n", .{cw.state().password()});
}
