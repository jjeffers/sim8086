const std = @import("std");
const lib = @import("sim8086_lib");

const OpCodeType = enum {
    None,
    mov,
};

const Instruction = struct {
    opcode: OpCodeType,
    size: u8,
};

pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = allocator.allocator();

    const input_listing_null_terminated: [*:0]u8 = std.os.argv[1];
    const input_listing: [:0]const u8 = std.mem.span(input_listing_null_terminated);

    const file = try std.fs.cwd().openFile(input_listing, .{ .mode = .read_only });
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try file.readToEndAlloc(alloc, file_size);

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    try stdout.print("bits 16\n", .{});

    var instructions_lookup = std.AutoHashMap(u8, Instruction).init(alloc);
    defer instructions_lookup.deinit();

    try instructions_lookup.put(0b10001001, Instruction{ .opcode = OpCodeType.mov, .size = 2 });

    try Disassemble(buffer, file_size, instructions_lookup, stderr);
}

pub fn Disassemble(memory_buffer: []u8, memory_size: u64, instructions_lookup: std.AutoHashMap(u8, Instruction), stderr: anytype) !void {
    var memory_buffer_index: u32 = 0;

    while (memory_buffer_index < memory_size) {
        const opcode = memory_buffer[memory_buffer_index];
        const instruction = instructions_lookup.get(opcode);

        if (instruction) |inst| {
            if ((memory_buffer_index + inst.size) <= memory_size) {
                memory_buffer_index += inst.size;
            } else {
                try stderr.print("ERROR: Instruction extends outside disassembly region\n", .{});
                break;
            }
        } else {
            try stderr.print("ERROR: Unrecognized binary in instruction stream.\n", .{});
            break;
        }
    }
}
