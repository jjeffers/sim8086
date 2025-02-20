
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

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("sim8086_lib");
