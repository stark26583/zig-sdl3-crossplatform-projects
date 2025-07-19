const constants = @import("constants.zig");
const std = @import("std");

// Provided by executor.
extern var vert_index: u32 addrspace(.input);

// Data to output.
extern var vert_out_position: constants.vert_out_position_type addrspace(.output);
extern var vert_out_color: constants.vert_out_frag_in_color.typ addrspace(.output);

export fn main() callconv(.spirv_vertex) void {

    // Vertex index and position are built-ins.
    std.gpu.vertexIndex(&vert_index);
    std.gpu.position(&vert_out_position);

    // Export the color to a pre-selected slot.
    std.gpu.location(&vert_out_color, constants.vert_out_frag_in_color.loc);

    // Since we are drawing 1 primitive triangle, the indices 0, 1, and 2 are the only vetices expected.
    switch (vert_index) {
        0 => {
            vert_out_position = .{ -1, -1, 0, 1 };
            vert_out_color = .{ 1, 0, 0, 1 };
        },
        1 => {
            vert_out_position = .{ 1, -1, 0, 1 };
            vert_out_color = .{ 0, 1, 0, 1 };
        },
        else => {
            vert_out_position = .{ 0, 1, 0, 1 };
            vert_out_color = .{ 0, 0, 1, 1 };
        },
    }
}
