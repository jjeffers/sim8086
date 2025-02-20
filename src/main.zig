
pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = allocator.allocator();

    const input_listing_null_terminated: [*:0]u8 = std.os.argv[1];
    const input_listing: [:0]const u8 = std.mem.span(input_listing_null_terminated);

    const file = try std.fs.cwd().openFile(input_listing, .{ .mode = .read_only });
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try file.readToEndAlloc(alloc, file_size);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("bits 16\n", .{});

    var instructions_lookup = std.AutoHashMap(u8, Instruction).init(alloc);
    defer instructions_lookup.deinit();

    const instructins = [_]std.meta.FieldInfo(u8, Instruction){ 
        .{0b10001001, .{ OpCodeType.mov, 2 } } 
    };

    for (static_list) |pair| {
        try map.put(pair.key, pair.value);
    }


    Disassemble(buffer, file_size, instructions_lookup);

    try bw.flush(); // Don't forget to flush!

}

const OpCodeType = enum 
{
    None,
    mov,
};

const Instruction = struct
{
    opcode: OpCodeType,
    size: u8,
};




pub fn Disassemble(memory_buffer: []u8, memory_size: u32, instructions_lookup: std.AutoHashMap) void {

    var memory_buffer_index : u32 = 0;
    
    while(memory_buffer_index <= memory_size) {
        
        var opcode = memory_buffer[memory_buffer_index];
        var instruction = instructions_lookup.get(opcode);

        if(instruction) |inst|
        {
            if((memory_buffer_index + Instruction.Size) <= memory_size)
            {
                memory_buffer_index += Instruction.Size;
            }
            else
            {
                stderr.print("ERROR: Instruction extends outside disassembly region\n");
                break;
            }
        }
        else
        {
            stderr.print("ERROR: Unrecognized binary in instruction stream.\n");
            break;
        }
    }
}

/*
    {
    var opcode_byte: [1]u8 = undefined;
    var register_byte: [1]u8 = undefined;

    var memory_index = 0;
    while (memory_index <= file_size) {
        const opcode_bytes_read = try reader.read(&opcode_byte);

        if (opcode_bytes_read == 0) {
            break;
        }

        // 6 bits == opcode, plus 2 bits:
        // D (direction, 0=source is in REG/1=dest in REG)
        // W  (0=1 byte data, 1=word data)

        // read fist 6 bits
        const opcode = opcode_byte[0] >> 2;
        const d_bit = (0b10 & opcode_byte[0]) >> 1;
        try stdout.print("d bit is 0x{x}\n", .{d_bit});
        const w_bit = (0b01 & opcode_byte[0]);
        try stdout.print("w bit is 0x{x}\n", .{w_bit});

        try stdout.print("opcode 0x{x}\n", .{opcode});
        if (opcode == 0x22) {
            const instruction = "mov";

            const register_bytes_read = try reader.read(&register_byte);

            if (register_bytes_read == 0) {
                break;
            }

            const register_mode = (0b11000000 & register_byte[0]) >> 6;

            try stdout.print("REG mode is 0x{x}\n", .{register_mode});
            const register_operand = (0b00111000 & register_byte[0]) >> 3;
            try stdout.print("REG operand 0x{x}\n", .{register_operand});
            const rm = (0b00000111 & register_byte[0]);
            try stdout.print("R/M is 0x{x}\n", .{rm});

            var destination_register = undefined;
            var source_register = undefined;

            if (register_mode == 0b11) {
                try stdout.print("register to register mode\n", .{});
            }

            if (register_operand == 0b11) {
                try stdout.print("source register operand is 'cx'", .{});
                if (d_bit == 0) {
                    source_register = "cx";

                    if (rm == 0b1) {
                        destination_register = "bx";
                    }
                }
            }

            try stdout.print("{s} {s}, {s}", .{ instruction, destination_register, source_register });
        }
    }

    try bw.flush(); // Don't forget to flush!
}
*/

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("sim8086_lib");
