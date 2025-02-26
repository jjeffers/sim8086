const std = @import("std");
const lib = @import("sim8086_lib");
const decode = @import("decode.zig");

pub fn buildInstructionLookup(alloc: std.mem.Allocator) !std.AutoHashMap(u8, decode.Instruction) {
    var instructions_lookup = std.AutoHashMap(u8, decode.Instruction).init(alloc);

    try instructions_lookup.put(0b100010, decode.Instruction{
        .opcode = decode.OpCodeType.mov,
        .size = 2,
        .asm_text = "mov",
    });

    return instructions_lookup;
}

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

    try stdout.print("bits 16\n\n", .{});

    const instructions_lookup = try buildInstructionLookup(alloc);

    try Disassemble(buffer, file_size, instructions_lookup, stdout, stderr);
}

pub fn printInstruction(instruction: []const u8, destination: [:0]const u8, source: [:0]const u8, stdout: anytype) !void {
    try stdout.print("{s} {s}, {s}\n", .{ instruction, destination, source });
}

pub fn Disassemble(memory_buffer: []u8, memory_size: u64, instructions_lookup: std.AutoHashMap(u8, decode.Instruction), stdout: anytype, stderr: anytype) !void {
    var memory_buffer_index: u32 = 0;

    while (memory_buffer_index < memory_size) {
        const byte1 = memory_buffer[memory_buffer_index];
        const byte2 = memory_buffer[memory_buffer_index + 1];

        const opcode = (byte1 & decode.OpCodeBitmask) >> 2;

        const instruction = instructions_lookup.get(opcode);
        if (instruction) |inst| {
            const register_mode = (byte2 & decode.ModeBitmask) >> 6;

            const direction_bit = (byte1 & decode.DirectionBitBitmask) >> 1;
            const word_bit = byte1 & decode.WordByteBitBitmask;

            const reg_bits = (byte2 & decode.RegBitmask) >> 3;
            const rm_bits = (byte2 & decode.RMBitmask);

            const operands = decode.getOperands(@enumFromInt(register_mode), @enumFromInt(direction_bit), @enumFromInt(word_bit), reg_bits, rm_bits);

            try printInstruction(inst.asm_text, @tagName(operands.destination), @tagName(operands.source), stdout);

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
