const std = @import("std");
const lib = @import("sim8086_lib");

const OpCodeType = enum {
    None,
    mov,
};

const WordByteBitBitmask = 0b01;
const WordByteBit = enum {
    Byte,
    Word,
};

const DirectionBitBitmask = 0b10;

const DirectionBit = enum {
    RegisterIsSource,
    RegisterIsDestination,
};

const ModeBitmask = 0b1100000;

const Mode = enum(u8) {
    MemoryMode = 0b00,
    MemoryMode8BitDisplacement = 0b01,
    MemoryMode16Bit = 0b10,
    RegisterMode = 0b11,
};

const RegBitmask = 0b00111000;
const RMBitmask = 0b00000111;

const Register = enum {
    al,
    ah,
    ax,
    bl,
    bh,
    bx,
    cl,
    ch,
    cx,
    dl,
    dh,
    dx,
    sp,
    bp,
    si,
    di,
};

const register_field_lookup: [8][2]Register = [_][2]Register{
    [_]Register{ Register.al, Register.ax },
    [_]Register{ Register.cl, Register.cx },
    [_]Register{ Register.dl, Register.dx },
    [_]Register{ Register.bl, Register.bx },
    [_]Register{ Register.ah, Register.sp },
    [_]Register{ Register.ch, Register.bp },
    [_]Register{ Register.dh, Register.si },
    [_]Register{ Register.bh, Register.di },
};

const InstructionBitFields = enum {
    Direction,
    WordOrByte,
    Register_Mode,
    Register_Operand,
    Register_RM,
};

const Instruction = struct {
    opcode: OpCodeType,
    size: u8,
    asm_text: []const u8,
};

pub fn buildInstructionLookup(alloc: std.mem.Allocator) !std.AutoHashMap(u8, Instruction) {
    var instructions_lookup = std.AutoHashMap(u8, Instruction).init(alloc);

    try instructions_lookup.put(0b10001001, Instruction{
        .opcode = OpCodeType.mov,
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

    try stdout.print("bits 16\n", .{});

    const instructions_lookup = try buildInstructionLookup(alloc);

    try Disassemble(buffer, file_size, instructions_lookup, stdout, stderr);
}

pub fn printInstruction(instruction: []const u8, destination: [:0]const u8, source: [:0]const u8, stdout: anytype) !void {
    try stdout.print("{s} {s}, {s}\n", .{ instruction, destination, source });
}

pub fn Disassemble(memory_buffer: []u8, memory_size: u64, instructions_lookup: std.AutoHashMap(u8, Instruction), stdout: anytype, stderr: anytype) !void {
    var memory_buffer_index: u32 = 0;

    while (memory_buffer_index < memory_size) {
        const opcode = memory_buffer[memory_buffer_index];
        const byte2 = memory_buffer[memory_buffer_index + 1];

        const instruction = instructions_lookup.get(opcode);
        if (instruction) |inst| {
            const register_mode = byte2 & ModeBitmask >> 6;

            const direction_bit = opcode & DirectionBitBitmask >> 1;
            const word_bit = opcode & WordByteBitBitmask;

            var source: Register = undefined;
            var destination: Register = undefined;

            if (register_mode == @intFromEnum(Mode.RegisterMode)) {
                const reg_bits = byte2 & RegBitmask >> 3;
                const rm_bits = byte2 & RMBitmask;

                if (direction_bit == @intFromEnum(DirectionBit.RegisterIsSource)) {
                    source = register_field_lookup[word_bit][reg_bits];
                    destination = register_field_lookup[word_bit][rm_bits];
                } else {
                    destination = register_field_lookup[word_bit][reg_bits];
                    source = register_field_lookup[word_bit][rm_bits];
                }
            }

            try printInstruction(inst.asm_text, @tagName(destination), @tagName(source), stdout);

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
