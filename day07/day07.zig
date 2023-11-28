const std = @import("std");

const Command = struct {
    const Cmd = enum { CD, LS };
    cmd: Cmd,
    arg: []const u8,
};

fn logGetCommand(line: []const u8) ?Command {
    if (line.len >= 5 and std.mem.eql(u8, line[0..5], "$ cd ")) {
        return Command{ .cmd = Command.Cmd.CD, .arg = line[5..] };
    } else if (std.mem.eql(u8, line, "$ ls")) {
        return Command{ .cmd = Command.Cmd.LS, .arg = "" };
    }
    return null;
}

fn logGetDir(line: []const u8) ?[]const u8 {
    if (line.len > 4 and std.mem.eql(u8, line[0..4], "dir ")) {
        return line[4..];
    } else {
        return null;
    }
}

const File = struct {
    size: usize,
    name: []const u8,
};

fn logGetFile(line: []const u8) !?File {
    if (std.mem.indexOfScalar(u8, line, ' ')) |spaceIdx| {
        const size = std.fmt.parseInt(usize, line[0..spaceIdx], 10) catch |err| switch (err) {
            std.fmt.ParseIntError.InvalidCharacter => return null,
            else => return err,
        };
        return File{ .size = size, .name = line[spaceIdx + 1 ..] };
    } else {
        return null;
    }
}

const FsEntry = union(enum) { file: usize, directory: std.StringHashMap(FsEntry) };

fn directorySum(root: *std.StringHashMap(FsEntry), x: *usize) usize {
    var sum: usize = 0;
    var it = root.iterator();
    while (it.next()) |entry| {
        sum += switch (entry.value_ptr.*) {
            FsEntry.file => |size| size,
            FsEntry.directory => |*dir| directorySum(dir, x),
        };
    }
    if (sum <= 100000) {
        x.* += sum;
    }
    return sum;
}

fn smallestToDelete(root: *std.StringHashMap(FsEntry), minSize: usize, x: *usize) usize {
    var sum: usize = 0;
    var it = root.iterator();
    while (it.next()) |entry| {
        sum += switch (entry.value_ptr.*) {
            FsEntry.file => |size| size,
            FsEntry.directory => |*dir| smallestToDelete(dir, minSize, x),
        };
    }
    if (sum >= minSize and sum < x.*) {
        x.* = sum;
    }
    return sum;
}

fn freeTree(root: *std.StringHashMap(FsEntry)) void {
    var it = root.iterator();
    while (it.next()) |entry| {
        switch (entry.value_ptr.*) {
            FsEntry.directory => |*dir| {
                freeTree(dir);
            },
            else => {},
        }
    }
    root.deinit();
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var log = std.ArrayList([]u8).init(allocator);
    defer {
        for (log.items) |line| {
            allocator.free(line);
        }
        log.deinit();
    }
    while (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
        try log.append(line);
    }

    var root = std.StringHashMap(FsEntry).init(allocator);
    defer freeTree(&root);
    var stack = std.ArrayList(*std.StringHashMap(FsEntry)).init(allocator);
    defer stack.deinit();

    var cwd = &root;

    for (log.items) |line| {
        if (logGetCommand(line)) |cmd| {
            if (cmd.cmd == Command.Cmd.LS) {
                continue;
            }
            if (std.mem.eql(u8, cmd.arg, "/")) {
                cwd = &root;
                stack.clearAndFree();
            } else if (std.mem.eql(u8, cmd.arg, "..")) {
                cwd = stack.pop();
            } else {
                try stack.append(cwd);
                cwd = &cwd.getPtr(cmd.arg).?.directory;
            }
        } else if (logGetDir(line)) |dirname| {
            if (!cwd.contains(dirname)) {
                try cwd.put(dirname, FsEntry{ .directory = std.StringHashMap(FsEntry).init(allocator) });
            }
        } else if (try logGetFile(line)) |file| {
            try cwd.put(file.name, FsEntry{ .file = file.size });
        } else {
            return error.InvalidLog;
        }
    }

    var x: usize = 0;
    const used = directorySum(&root, &x);
    try stdout.print("part 1: {}\n", .{x});

    const required = 30000000;
    const available = 70000000;
    const free = available - used;
    std.debug.assert(free < required);

    x = std.math.maxInt(usize);
    _ = smallestToDelete(&root, required - free, &x);
    try stdout.print("part 2: {}\n", .{x});
}
