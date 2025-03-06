const std = @import("std");
const fs = std.fs;
const Child = std.process.Child;

test "generate and compare assembled binary files" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("leak");
    const allocator = gpa.allocator();

    // In order to walk the directry, `iterate` must be set to true.
    var dir = try fs.cwd().openDir("test", .{ .iterate = true });
    defer dir.close();

    try dir.setAsCwd();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const result = try compileAndCompareAssembly(entry);
        try std.testing.expect(result);
    }
}

fn compileAndCompareAssembly(listing: fs.Dir.Walker.Entry) !bool {
    const ext = std.fs.path.extension(listing.path);
    if (std.mem.eql(u8, ext, ".asm")) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer if (gpa.deinit() != .ok) @panic("leak");
        const allocator = gpa.allocator();

        std.debug.print("Found file: {s}\n", .{listing.basename});

        const baseName = fs.path.stem(listing.basename);

        const nasm_argv = [_][]const u8{
            "nasm",
            "-o",
            baseName,
            listing.path,
        };

        try std.testing.expectEqual(exec(&nasm_argv, allocator, null), 0);

        const sim8086_disassembly = try std.fmt.allocPrint(allocator, "{s}.sim8086_asm", .{baseName});
        defer allocator.free(sim8086_disassembly);

        const decode_file = try std.fs.cwd().createFile(sim8086_disassembly, .{});
        defer decode_file.close();

        const sim8086_argv = [_][]const u8{
            "../zig-out/bin/sim8086",
            baseName,
        };

        const stdout_writer = decode_file.writer();

        try std.testing.expectEqual(exec(&sim8086_argv, allocator, stdout_writer), 0);

        try assertfFileExists(sim8086_disassembly);

        const sim8086_assembly = try std.fmt.allocPrint(allocator, "{s}.sim8086", .{baseName});
        defer allocator.free(sim8086_assembly);

        const sim8086_nasm_argv = [_][]const u8{
            "nasm",
            "-o",
            sim8086_assembly,
            sim8086_disassembly,
        };

        try std.testing.expectEqual(exec(&sim8086_nasm_argv, allocator, null), 0);

        try assertfFileExists(sim8086_assembly);

        try assertFilesMatchAllBytes(baseName, sim8086_assembly, allocator);
    }
    return true;
}

fn assertFilesMatchAllBytes(expected_filename: []const u8, actual_filename: []const u8, allocator: std.mem.Allocator) !void {
    const expected = try std.fs.cwd().openFile(expected_filename, .{});
    defer expected.close();

    const actual = try std.fs.cwd().openFile(actual_filename, .{});
    defer actual.close();

    const expected_size = try expected.getEndPos();
    const actual_size = try actual.getEndPos();

    try std.testing.expectEqual(expected_size, actual_size);

    const expected_buffer = try allocator.alloc(u8, expected_size);
    defer allocator.free(expected_buffer);

    const actual_buffer = try allocator.alloc(u8, actual_size);
    defer allocator.free(actual_buffer);

    _ = try expected.read(expected_buffer);
    _ = try actual.read(actual_buffer);

    for (expected_buffer, 0..) |byte1, i| {
        if (byte1 != actual_buffer[i]) {
            std.debug.print("expected byte # {} to be {b}, found {b}\n", .{ i, byte1, actual_buffer[i] });
            return error.TestExpectedEqual;
        }
    }
}

pub fn assertfFileExists(filename: []u8) !void {
    var found = true;
    std.fs.cwd().access(filename, .{}) catch |e| switch (e) {
        error.FileNotFound => found = false,
        else => return e,
    };
    try std.testing.expect(found);
}

pub fn exec(argv: []const []const u8, allocator: std.mem.Allocator, stdout_writer: ?fs.File.Writer) !u8 {
    var child = Child.init(argv, allocator);

    if (stdout_writer) |_| {
        child.stdout_behavior = .Pipe;
    }

    try child.spawn();

    if (stdout_writer) |writer| {
        const max_output_size = 100 * 1024 * 1024;
        const stdout = child.stdout.?.reader();
        const bytes = try stdout.readAllAlloc(allocator, max_output_size);
        defer allocator.free(bytes);
        try writer.writeAll(bytes);
    }

    const term = try child.wait();

    return term.Exited;
}
