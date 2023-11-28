const std = @import("std");

const Shape = enum(u32) {
    Rock = 1,
    Paper = 2,
    Scissors = 3,

    const Self = @This();
    const Error = error{UnknownShape};

    fn init(shapeChar: u8) !Self {
        return switch (shapeChar) {
            'A', 'X' => Self.Rock,
            'B', 'Y' => Self.Paper,
            'C', 'Z' => Self.Scissors,
            else => Self.Error.UnknownShape,
        };
    }

    fn score(self: Self) u32 {
        return @intFromEnum(self);
    }

    fn playAgainst(self: Self, other: Self) u32 {
        if (other == self.winAgainstShape()) {
            return 6 + self.score();
        } else if (self == other) {
            return 3 + self.score();
        } else {
            return self.score();
        }
    }

    fn winAgainstShape(self: Self) Self {
        return switch (self) {
            Self.Rock => Self.Scissors,
            Self.Paper => Self.Rock,
            Self.Scissors => Self.Paper,
        };
    }

    fn loseAgainstShape(self: Self) Self {
        return switch (self) {
            Self.Rock => Self.Paper,
            Self.Paper => Self.Scissors,
            Self.Scissors => Self.Rock,
        };
    }
};

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buffer: [4]u8 = undefined;
    var score1: u32 = 0;
    var score2: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        const opponentShape = try Shape.init(line[0]);
        const myShape = try Shape.init(line[2]);
        score1 += myShape.playAgainst(opponentShape);
        switch (line[2]) {
            'X' => score2 += opponentShape.winAgainstShape().playAgainst(opponentShape),
            'Y' => score2 += opponentShape.playAgainst(opponentShape),
            'Z' => score2 += opponentShape.loseAgainstShape().playAgainst(opponentShape),
            else => return Shape.Error.UnknownShape,
        }
    }

    try stdout.print("part 1: {}\n", .{score1});
    try stdout.print("part 2: {}\n", .{score2});
}
