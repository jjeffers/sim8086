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

        const sim8086_disassembly = try std.fmt.allocPrint(allocator, "{s}.asm", .{baseName});
        defer allocator.free(sim8086_disassembly);

        const sim8086_argv = [_][]const u8{
            "../zig-out/bin/sim8086",
            baseName,
            ">",
            sim8086_disassembly,
        };

        var sim8086 = Child.init(&sim8086_argv, allocator);

        try sim8086.spawn();
        const sim8086_term = try sim8086.wait();

        try std.testing.expectEqual(sim8086_term.Exited, 0);

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
