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

        var nasm = Child.init(&nasm_argv, allocator);

        try nasm.spawn();
        const term = try nasm.wait();
        try std.testing.expectEqual(term.Exited, 0);

        const sim8086_disassembly = try std.fmt.allocPrint(allocator, "{s}.sim8086_asm", .{baseName});
        defer allocator.free(sim8086_disassembly);

        const decode_file = try std.fs.cwd().createFile(sim8086_disassembly, .{});
        defer decode_file.close();

        const sim8086_argv = [_][]const u8{
            "../zig-out/bin/sim8086",
            baseName,
        };

        var sim8086 = Child.init(&sim8086_argv, allocator);
        sim8086.stdout_behavior = .Pipe;

        try sim8086.spawn();
        const stdout = sim8086.stdout.?.reader();
        const stdout_writer = decode_file.writer();

        const max_output_size = 100 * 1024 * 1024;
        const bytes = try stdout.readAllAlloc(allocator, max_output_size);
        defer allocator.free(bytes);

        try stdout_writer.writeAll(bytes);

        const sim8086_term = try sim8086.wait();

        try std.testing.expectEqual(sim8086_term.Exited, 0);

        const decode_stat = try std.fs.cwd().statFile(sim8086_disassembly);

        try std.testing.expectEqual(decode_stat.kind, .file);

        const sim8086_assembly = try std.fmt.allocPrint(allocator, "{s}.sim8086", .{baseName});
        defer allocator.free(sim8086_assembly);

        const sim8086_nasm_argv = [_][]const u8{
            "nasm",
            "-o",
            sim8086_assembly,
            sim8086_disassembly,
        };

        var sim8086_nasm = Child.init(&sim8086_nasm_argv, allocator);

        try sim8086_nasm.spawn();
        const sim8086_nasm_term = try sim8086_nasm.wait();

        try std.testing.expectEqual(sim8086_nasm_term.Exited, 0);
    }
    return true;
}
