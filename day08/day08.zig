const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var input = std.ArrayList([]const u8).init(allocator);
    var viewingDistances = std.ArrayList([][4]usize).init(allocator);
    defer {
        for (input.items, 0..) |row, i| {
            allocator.free(row);
            allocator.free(viewingDistances.items[i]);
        }
        input.deinit();
        viewingDistances.deinit();
    }

    while (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
        for (line) |*tree| {
            tree.* -= '0';
        }
        try input.append(line);
        try viewingDistances.append(try allocator.alloc([4]usize, line.len));
    }
    std.debug.assert(input.items.len == input.items[0].len);

    const map = input.items;
    const n = map.len;
    var i: usize = 0;
    var j: usize = 0;

    while (i < n) : (i += 1) {
        var lastSeenRowPrefix = [_]usize{0} ** 10;
        var lastSeenRowSuffix = [_]usize{0} ** 10;
        var lastSeenColPrefix = [_]usize{0} ** 10;
        var lastSeenColSuffix = [_]usize{0} ** 10;

        var k: usize = 0;
        while (k < 10) : (k += 1) {
            lastSeenRowSuffix[k] = n - 1;
            lastSeenColSuffix[k] = n - 1;
        }

        j = 0;

        while (j < n) : (j += 1) {
            const rowPrefixTree = map[i][j];
            const lastSeenRowPrefixTree = std.mem.max(usize, lastSeenRowPrefix[rowPrefixTree..]);
            viewingDistances.items[i][j][0] = j - lastSeenRowPrefixTree;
            lastSeenRowPrefix[rowPrefixTree] = j;

            const rowSuffixTree = map[i][n - j - 1];
            const lastSeenRowSuffixTree = std.mem.min(usize, lastSeenRowSuffix[rowSuffixTree..]);
            viewingDistances.items[i][n - j - 1][1] = lastSeenRowSuffixTree - (n - j - 1);
            lastSeenRowSuffix[rowSuffixTree] = n - j - 1;

            const colPrefixTree = map[j][i];
            const lastSeenColPrefixTree = std.mem.max(usize, lastSeenColPrefix[colPrefixTree..]);
            viewingDistances.items[j][i][2] = j - lastSeenColPrefixTree;
            lastSeenColPrefix[colPrefixTree] = j;

            const colSuffixTree = map[n - j - 1][i];
            const lastSeenColSuffixTree = std.mem.min(usize, lastSeenColSuffix[colSuffixTree..]);
            viewingDistances.items[n - j - 1][i][3] = lastSeenColSuffixTree - (n - j - 1);
            lastSeenColSuffix[colSuffixTree] = n - j - 1;
        }
    }

    var visibleCount: usize = 0;
    var maxScenicScore: usize = 0;

    for (viewingDistances.items, 0..) |row, r| {
        for (row, 0..) |vd, c| {
            if (r == 0 or r == n - 1 or c == 0 or c == n - 1 or
                (c - vd[0] == 0 and map[r][0] < map[r][c]) or
                (c + vd[1] == n - 1 and map[r][n - 1] < map[r][c]) or
                (r - vd[2] == 0 and map[0][c] < map[r][c]) or
                (r + vd[3] == n - 1 and map[n - 1][c] < map[r][c]))
            {
                visibleCount += 1;
            }
            maxScenicScore = @max(maxScenicScore, vd[0] * vd[1] * vd[2] * vd[3]);
        }
    }

    try stdout.print("part 1: {}\n", .{visibleCount});
    try stdout.print("part 2: {}\n", .{maxScenicScore});
}
