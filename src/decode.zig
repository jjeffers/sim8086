const std = @import("std");

pub const OpCodeBitmask = 0b11111100;

pub const OpCodeType = enum {
    None,
    mov,
};

pub const WordByteBitBitmask = 0b01;
const WordByteBit = enum {
    Byte,
    Word,
};

pub const DirectionBitBitmask = 0b10;

const DirectionBit = enum {
    RegisterIsSource,
    RegisterIsDestination,
};

pub const ModeBitmask = 0b11000000;

const Mode = enum(u8) {
    MemoryMode = 0b00,
    MemoryMode8BitDisplacement = 0b01,
    MemoryMode16Bit = 0b10,
    RegisterMode = 0b11,
};

pub const RegBitmask = 0b00111000;
pub const RMBitmask = 0b00000111;

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

pub const register_field_lookup: [8][2]Register = [_][2]Register{
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

pub const Instruction = struct {
    opcode: OpCodeType,
    size: u8,
    asm_text: []const u8,
};

pub fn getOperands(mode: Mode, d_bit: DirectionBit, w_bit: WordByteBit, reg_bits: u8, rm_bits: u8) struct { destination: Register, source: Register } {
    var src: Register = Register.al;
    var dest: Register = Register.al;
    const w_value = @intFromEnum(w_bit);

    if (mode == Mode.RegisterMode) {
        if (d_bit == DirectionBit.RegisterIsSource) {
            src = register_field_lookup[reg_bits][w_value];
            dest = register_field_lookup[rm_bits][w_value];
        } else {
            const maybe = register_field_lookup[rm_bits][w_value];
            dest = maybe;
            dest = register_field_lookup[reg_bits][w_value];
            src = register_field_lookup[rm_bits][w_value];
        }
    }

    return .{ .destination = dest, .source = src };
}

test "direction bit as 'reg is source', w_bit is 'word', reg is 'BX' yields source as 'bx'" {
    const operands = getOperands(Mode.RegisterMode, DirectionBit.RegisterIsSource, WordByteBit.Word, 0b011, 0b000);
    try std.testing.expectEqual(Register.bx, operands.source);
}

test "direction bit as 'reg is source', w_bit is 'word', rm is 'CX' yields destination as 'cx'" {
    const operands = getOperands(Mode.RegisterMode, DirectionBit.RegisterIsSource, WordByteBit.Word, 0b011, 0b001);
    try std.testing.expectEqual(Register.cx, operands.destination);
}

test "direction bit as 'reg is destination', w_bit is 'word', reg is 'BX' yields destination as 'bx'" {
    const operands = getOperands(Mode.RegisterMode, DirectionBit.RegisterIsDestination, WordByteBit.Word, 0b011, 0b000);
    try std.testing.expectEqual(Register.bx, operands.destination);
}
