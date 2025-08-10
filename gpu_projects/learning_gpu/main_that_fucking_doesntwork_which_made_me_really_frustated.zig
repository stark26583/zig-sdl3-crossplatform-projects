const std = @import("std");
const sdl3 = @import("Cat");
const zstbi = sdl3.zstbi;
const FpsManager = sdl3.FpsManager;
const assets = @import("assets");
const shaders = @import("shaders");

const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 780;

const assert = std.debug.assert;

const vertex_shader_code = shaders.@"shader.vertex.spirv";
const fragment_shader_code = shaders.@"shader.fragment.spirv";

pub fn main() !void {
    defer sdl3.shutdown();

    sdl3.log.setAllPriorities(.verbose);

    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    zstbi.init(allocator);
    defer zstbi.deinit();

    const window = try sdl3.video.Window.init("GPU programming", SCREEN_WIDTH, SCREEN_HEIGHT, .{});
    defer window.deinit();

    var fps_manager = FpsManager.init(.none);

    const gpu = try sdl3.gpu.Device.init(.{ .spirv = true }, true, null);
    defer gpu.deinit();

    try gpu.claimWindow(window);
    defer gpu.releaseWindow(window);

    const vertex_shader = try loadShader(
        gpu,
        vertex_shader_code,
        .vertex,
        1,
        0,
    );
    defer gpu.releaseShader(vertex_shader);
    const fragment_shader = try loadShader(
        gpu,
        fragment_shader_code,
        .fragment,
        0,
        1,
    );
    defer gpu.releaseShader(fragment_shader);

    //Create Texture
    var image = try zstbi.Image.loadFromMemory(assets.images.@"trees.jpeg", 4);
    defer image.deinit();
    const pixels_byte_size = image.width * image.height * 4;

    const texture = try gpu.createTexture(.{
        .texture_type = .two_dimensional,
        .width = image.width,
        .height = image.height,
        .format = .r8g8b8a8_unorm,
        .usage = .{ .sampler = true },
        .num_levels = 1,
        .layer_count_or_depth = 1,
    });
    defer gpu.releaseTexture(texture);
    // create vertex data

    const Vec3 = @Vector(3, f32);
    const Color = @Vector(4, f32);
    const Vertex = struct {
        position: Vec3,
        color: Color,
        uv: @Vector(2, f32),
    };

    const White: Color = .{ 1.0, 1.0, 1.0, 1.0 };
    // const Green: Color = .{ 0.0, 1.0, 0.0, 1.0 };
    const tint = White;

    const vertices = [_]Vertex{
        .{ .position = .{ -0.5, 0.5, 0.0 }, .color = tint, .uv = .{ 0.0, 0.0 } }, //top left
        .{ .position = .{ 0.5, 0.5, 0.0 }, .color = tint, .uv = .{ 1.0, 0.0 } }, //top right
        .{ .position = .{ -0.5, -0.5, 0.0 }, .color = tint, .uv = .{ 0.0, 1.0 } }, //bottom left
        .{ .position = .{ 0.5, -0.5, 0.0 }, .color = tint, .uv = .{ 1.0, 1.0 } }, //bottom right
    };
    const vertices_byte_size = vertices.len * @sizeOf(@TypeOf(vertices[0]));

    const indices = [_]u16{
        0, 1, 2,
        2, 1, 3,
    };
    const indices_byte_size = indices.len * @sizeOf(@TypeOf(indices[0]));

    // describe vertex attributes and vertex buffers in pipline
    const vertex_attributes = [_]sdl3.gpu.VertexAttribute{
        .{
            .location = 0,
            .buffer_slot = 0,
            .format = .f32x3,
            .offset = @offsetOf(Vertex, "position"),
        },
        .{
            .location = 1,
            .buffer_slot = 0,
            .format = .f32x4,
            .offset = @offsetOf(Vertex, "color"),
        },
        .{
            .location = 2,
            .buffer_slot = 0,
            .format = .f32x2,
            .offset = @offsetOf(Vertex, "uv"),
        },
    };

    const vertex_buffer_descriptions = [_]sdl3.gpu.VertexBufferDescription{
        .{
            .slot = 0,
            .pitch = @sizeOf(Vertex),
            .input_rate = .vertex,
        },
    };

    // create vertex buffer
    const vertex_buffer = try gpu.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = @intCast(vertices_byte_size),
    });
    defer gpu.releaseBuffer(vertex_buffer);
    // create index buffer
    const index_buffer = try gpu.createBuffer(.{
        .usage = .{ .index = true },
        .size = @intCast(indices_byte_size),
    });
    defer gpu.releaseBuffer(index_buffer);

    const transfer_buffer = sdl3.c.SDL_CreateGPUTransferBuffer(gpu.value, &.{
        .usage = sdl3.c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .size = @intCast(vertices_byte_size + indices_byte_size),
    });
    defer sdl3.c.SDL_ReleaseGPUTransferBuffer(gpu.value, transfer_buffer);
    const transfer_memory_ptr = sdl3.c.SDL_MapGPUTransferBuffer(gpu.value, transfer_buffer, false);
    const vertex_dest_ptr: [*]u8 = @ptrCast(transfer_memory_ptr.?);
    const vertex_dest_slice = vertex_dest_ptr[0..vertices_byte_size];
    const index_dest_ptr: [*]u8 = @ptrFromInt(@as(usize, @intFromPtr(vertex_dest_ptr)) + vertices_byte_size);
    const index_dest_slice = index_dest_ptr[0..indices_byte_size];
    const vertex_source_ptr: [*]const u8 = @ptrCast(vertices[0..].ptr);
    const vertex_source_slice = vertex_source_ptr[0..vertices_byte_size];
    const index_source_ptr: [*]const u8 = @ptrCast(indices[0..].ptr);
    const index_source_slice = index_source_ptr[0..indices_byte_size];
    @memcpy(vertex_dest_slice, vertex_source_slice);
    @memcpy(index_dest_slice, index_source_slice);
    sdl3.c.SDL_UnmapGPUTransferBuffer(gpu.value, transfer_buffer);
    const transfer_buff_zig = sdl3.gpu.TransferBuffer{
        .value = transfer_buffer orelse unreachable,
    };

    const texture_transfer_buffer = sdl3.c.SDL_CreateGPUTransferBuffer(gpu.value, &.{
        .usage = sdl3.c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .size = @intCast(pixels_byte_size),
    });
    defer sdl3.c.SDL_ReleaseGPUTransferBuffer(gpu.value, texture_transfer_buffer);
    const texture_transfer_memory_ptr = sdl3.c.SDL_MapGPUTransferBuffer(gpu.value, texture_transfer_buffer, false);
    const texture_dest_ptr: [*]u8 = @ptrCast(texture_transfer_memory_ptr.?);
    const texture_dest_slice = texture_dest_ptr[0..pixels_byte_size];
    const texture_source_ptr: [*]const u8 = @ptrCast(image.data[0..].ptr);
    const texture_source_slice = texture_source_ptr[0..pixels_byte_size];
    @memcpy(texture_dest_slice, texture_source_slice);
    sdl3.c.SDL_UnmapGPUTransferBuffer(gpu.value, texture_transfer_buffer);
    const texture_transfer_buff_zig = sdl3.gpu.TransferBuffer{
        .value = texture_transfer_buffer orelse unreachable,
    };

    //--------------------------
    // - begin copy pass
    const copy_cmd_buffer = try gpu.acquireCommandBuffer();
    const copy_pass = copy_cmd_buffer.beginCopyPass();
    // - invoke upload commands
    copy_pass.uploadToBuffer(
        .{
            .transfer_buffer = transfer_buff_zig,
            .offset = 0,
        },
        .{
            .buffer = vertex_buffer,
            .offset = 0,
            .size = @intCast(vertices_byte_size),
        },
        false,
    );

    copy_pass.uploadToBuffer(
        .{
            .transfer_buffer = texture_transfer_buff_zig,
            .offset = vertices_byte_size,
        },
        .{
            .buffer = index_buffer,
            .offset = 0,
            .size = @intCast(indices_byte_size),
        },
        false,
    );

    copy_pass.uploadToTexture(
        .{
            .offset = 0,
            .transfer_buffer = texture_transfer_buff_zig,
        },
        .{
            .texture = texture,
            .width = image.width,
            .height = image.height,
            .depth = 1,
        },
        false,
    );
    copy_pass.end();
    try copy_cmd_buffer.submit();

    const sampler = try gpu.createSampler(.{});
    defer gpu.releaseSampler(sampler);

    const pipline = try gpu.createGraphicsPipeline(
        .{
            .vertex_shader = vertex_shader,
            .fragment_shader = fragment_shader,
            .primitive_type = .triangle_list,
            .vertex_input_state = .{
                .vertex_buffer_descriptions = &vertex_buffer_descriptions,
                .vertex_attributes = &vertex_attributes,
            },
            .target_info = .{
                .color_target_descriptions = &.{sdl3.gpu.ColorTargetDescription{
                    .format = gpu.getSwapchainTextureFormat(window),
                }},
            },
        },
    );
    defer gpu.releaseGraphicsPipeline(pipline);

    // const window_size = try window.getSize();

    var paused = false;
    while (true) {
        var c_sdl_event: sdl3.c.SDL_Event = undefined;
        while (sdl3.c.SDL_PollEvent(&c_sdl_event)) {
            // const guiConsumed = zgui_sdl.processEvent(&c_sdl_event);
            // _ = guiConsumed;
            //
            // const io = zgui.io;
            // if (io.getWantCaptureMouse() or io.getWantCaptureKeyboard() or io.getWantTextInput()) {
            //     continue;
            // }

            switch (sdl3.events.Event.fromSdl(c_sdl_event)) {
                .quit => return,
                .key_down => |key| {
                    if (key.key) |k| {
                        if (k == .ac_back) {
                            return;
                        }
                    }
                },
                .finger_down => |finger| {
                    _ = finger;
                    paused = !paused;
                },
                else => {},
            }
        }
        // Update game state
        fps_manager.tick();

        // render
        const cmd_buffer = try gpu.acquireCommandBuffer();
        const swapchain = try cmd_buffer.waitAndAcquireSwapchainTexture(window);

        //Begin render pass
        if (swapchain.texture) |swapchain_tex| {
            const color_targets = [_]sdl3.gpu.ColorTargetInfo{.{
                .texture = swapchain_tex,
                .load = .clear,
                .clear_color = .{ .r = 0.6, .g = 0.1, .b = 0.1, .a = 1.0 },
                .store = .store,
            }};

            const render_pass = cmd_buffer.beginRenderPass(&color_targets, null);

            render_pass.bindGraphicsPipeline(pipline);
            const bindings = [_]sdl3.gpu.BufferBinding{.{ .offset = 0, .buffer = vertex_buffer }};
            render_pass.bindVertexBuffers(0, &bindings);
            const index_binding: sdl3.gpu.BufferBinding = .{ .offset = 0, .buffer = index_buffer };
            render_pass.bindIndexBuffer(index_binding, .indices_16bit);
            const fragment_samplers_bindings = [_]sdl3.gpu.TextureSamplerBinding{.{ .texture = texture, .sampler = sampler }};
            render_pass.bindFragmentSamplers(0, &fragment_samplers_bindings);
            render_pass.drawIndexedPrimitives(indices.len, 1, 0, 0, 0);
            render_pass.end();
        }
        try cmd_buffer.submit();
    }
}

fn loadShader(device: sdl3.gpu.Device, code: []const u8, stage: sdl3.gpu.ShaderStage, num_uniform_buffers: u32, num_samplers: u32) !sdl3.gpu.Shader {
    return try device.createShader(
        .{
            .code = code,
            .entry_point = "main",
            .num_samplers = num_samplers,
            .num_uniform_buffers = num_uniform_buffers,
            .stage = stage,
            .format = .{ .spirv = true },
        },
    );
}
