const constants = @import("constants.zig");
const std = @import("std");

// Provided by the vertex buffer.
extern var vert_in_position: constants.vert_in_position.typ addrspace(.input);
extern var vert_in_color: constants.vert_in_color.typ addrspace(.input);

// Data to output.
extern var vert_out_position: constants.vert_out_position_type addrspace(.output);
extern var vert_out_color: constants.vert_out_frag_in_color.typ addrspace(.output);

export fn main() callconv(.spirv_vertex) void {

    // Setup vertex buffer inputs.
    std.gpu.location(&vert_in_position, constants.vert_in_position.loc);
    std.gpu.location(&vert_in_color, constants.vert_in_color.loc);

    // Vertex position is built-in.
    std.gpu.position(&vert_out_position);

    // Export the color to a pre-selected slot.
    std.gpu.location(&vert_out_color, constants.vert_out_frag_in_color.loc);

    // Just forward the position and color.
    vert_out_position = constants.vert_out_position_type{ vert_in_position[0], vert_in_position[1], vert_in_position[2], 1 };
    vert_out_color = vert_in_color;
}
