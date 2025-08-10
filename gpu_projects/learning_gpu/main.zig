const std = @import("std");
const sdl3 = @import("Cat");
const gpu = sdl3.gpu;
const assets = @import("assets");
const shaders = @import("shaders");

const zstbi = sdl3.zstbi;
const zmath = sdl3.zmath;
const zmesh = @import("zmesh");
const zgui = @import("zgui");
const zgui_sdl = zgui.backend;

const FPSCapper = sdl3.extras.FramerateCapper(f32);

const SCREEN_WIDTH = if (builtin.cpu.arch.isAARCH64()) 2412 else 1280;
const SCREEN_HEIGHT = if (builtin.cpu.arch.isAARCH64()) 1080 else 780;
const White: @Vector(4, u8) = .{ 255, 255, 255, 255 };
const Black: @Vector(4, u8) = .{ 0, 0, 0, 255 };
const Red: @Vector(4, u8) = .{ 255, 0, 0, 255 };
const Green: @Vector(4, u8) = .{ 0, 255, 0, 255 };
const Blue: @Vector(4, u8) = .{ 0, 0, 255, 255 };
const Yellow: @Vector(4, u8) = .{ 255, 255, 0, 255 };
const Cyan: @Vector(4, u8) = .{ 0, 255, 255, 255 };

const Camera = struct {
    const SENSITIVITY: f32 = 2;
    var w_pressed: bool = false;
    var a_pressed: bool = false;
    var s_pressed: bool = false;
    var d_pressed: bool = false;

    position: zmath.Vec,
    target: zmath.Vec,
};

const Vertex = packed struct {
    position: @Vector(3, f32),
    color: @Vector(4, u8),
    uv: @Vector(2, f32),
};

const UBO = struct {
    mvp: zmath.Mat,
};

pub fn main() !void {
    defer sdl3.shutdown();
    sdl3.log.setAllPriorities(.info);

    try sdl3.hints.set(.android_block_on_pause, "1");
    try sdl3.setAppMetadata("Learning GPU", "0.0.1", "STARK");
    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    zgui.init(allocator);
    defer zgui.deinit();
    zstbi.init(allocator);
    defer zstbi.deinit();
    zmesh.init(allocator);
    defer zmesh.deinit();

    const window = try sdl3.video.Window.init(
        "quad of my own?",
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        .{
            // .fullscreen = is_android,
        },
    );
    defer window.deinit();
    var window_size = try window.getSize();

    var fps_manager: FPSCapper = .{ .mode = .{ .unlimited = {} } };

    const device = try gpu.Device.init(.{ .spirv = builtin.os.tag != .windows, .dxil = builtin.os.tag == .windows }, true, null);
    defer device.deinit();
    try device.claimWindow(window);
    defer device.releaseWindow(window);
    const shader_format_supported = device.getShaderFormats();

    const driver_name = try device.getDriver();
    try zgui_style_init(window);

    zgui_sdl.init(window.value, .{
        .device = device.value,
        .color_target_format = @intFromEnum(device.getSwapchainTextureFormat(window)),
        .msaa_samples = 0,
    });
    defer zgui_sdl.deinit();

    //---------------------------GPU_Stuff--------------------------------

    const tint = Yellow;

    var mesh_shape = zmesh.Shape.initTrefoilKnot(10, 128, 0.8);
    defer mesh_shape.deinit();
    mesh_shape.rotate(std.math.pi * 0.5, 1.0, 0.0, 0.0);
    mesh_shape.unweld();
    mesh_shape.scale(0.5, 0.5, 0.5);

    // mesh_shape.translate(0, 0, 0);

    var vertices_arr = std.ArrayList(Vertex).init(allocator);
    defer vertices_arr.deinit();
    var indices_arr = std.ArrayList(u32).init(allocator);
    defer indices_arr.deinit();

    for (mesh_shape.indices) |index| {
        try indices_arr.append(index);
    }
    for (mesh_shape.positions, 0..) |position, i| {
        try vertices_arr.append(.{
            .position = .{ position[0], position[1], position[2] },
            .color = tint,
            .uv = if (mesh_shape.texcoords) |texcoord| .{ texcoord[i][0], texcoord[i][1] } else .{ 0.0, 0.0 },
        });
    }

    // for (vertices_arr.items) |vertex| {
    //     try log("position: ({d}, {d}, {d})", .{ vertex.position[0], vertex.position[1], vertex.position[2] });
    //     try log("color: ({d}, {d}, {d}, {d})", .{ vertex.color[0], vertex.color[1], vertex.color[2], vertex.color[3] });
    //     try log("uv: ({d}, {d})", .{ vertex.uv[0], vertex.uv[1] });
    // }

    var image = try zstbi.Image.loadFromMemory(assets.files.images.@"cobblestone.png", 4);
    defer image.deinit();

    const pixels_byte_size = image.width * image.height * 4;

    const vertices = vertices_arr.items;
    const vertices_byte_size: u32 = @intCast(vertices_arr.items.len * @sizeOf(@TypeOf(vertices[0])));

    const indices = indices_arr.items;
    const indices_byte_size: u32 = @intCast(indices.len * @sizeOf(@TypeOf(indices[0])));

    std.debug.assert(indices.len % 3 == 0);

    const vertex_shader = try device.createShader(.{
        .code = if (shader_format_supported.dxil) shaders.files.@"shader.vertex.dxil" else shaders.files.@"shader.vertex.spirv",
        .entry_point = "main",
        .format = .{ .dxil = shader_format_supported.dxil, .spirv = shader_format_supported.spirv and !(shader_format_supported.dxil) },
        .stage = .vertex,
        .num_uniform_buffers = 1,
    });
    defer device.releaseShader(vertex_shader);

    const fragment_shader = try device.createShader(.{
        .code = if (shader_format_supported.dxil) shaders.files.@"shader.fragment.dxil" else shaders.files.@"shader.fragment.spirv",
        .entry_point = "main",
        .format = .{ .dxil = shader_format_supported.dxil, .spirv = shader_format_supported.spirv and !(shader_format_supported.dxil) },
        .stage = .fragment,
        .num_samplers = 1,
        // .num_storage_textures = 1,
    });
    defer device.releaseShader(fragment_shader);

    const sampler = try device.createSampler(.{});
    defer device.releaseSampler(sampler);

    const depth_texture = try device.createTexture(.{
        .format = .depth24_unorm,
        .usage = .{ .depth_stencil_target = true },
        .width = @intCast(window_size.width),
        .height = @intCast(window_size.height),
        .layer_count_or_depth = 1,
        .num_levels = 1,
    });
    defer device.releaseTexture(depth_texture);

    const pipeline = try device.createGraphicsPipeline(
        .{
            .vertex_shader = vertex_shader,
            .fragment_shader = fragment_shader,
            .vertex_input_state = .{
                .vertex_attributes = &[_]gpu.VertexAttribute{
                    .{ .location = 0, .buffer_slot = 0, .format = .f32x3, .offset = @offsetOf(Vertex, "position") },
                    .{ .location = 1, .buffer_slot = 0, .format = .u8x4_normalized, .offset = @offsetOf(Vertex, "color") },
                    .{ .location = 2, .buffer_slot = 0, .format = .f32x2, .offset = @offsetOf(Vertex, "uv") },
                },
                .vertex_buffer_descriptions = &[_]gpu.VertexBufferDescription{
                    .{ .slot = 0, .pitch = @sizeOf(Vertex), .input_rate = .vertex },
                },
            },
            .primitive_type = .triangle_list,
            .target_info = .{
                .color_target_descriptions = &[_]gpu.ColorTargetDescription{
                    gpu.ColorTargetDescription{
                        .format = device.getSwapchainTextureFormat(window),
                        .blend_state = .{
                            // RGB:  new.rgb = src.rgb * src.a   +  dst.rgb * (1 - src.a)
                            .source_color = .src_alpha, // src.rgb * src.a
                            .destination_color = .one_minus_src_alpha, // dst.rgb * (1 - src.a)
                            .color_blend = .add, // add the two
                            // Alpha: new.a   = src.a     +  dst.a * (1 - src.a)
                            .source_alpha = .one, // keep the source α as is
                            .destination_alpha = .one_minus_src_alpha, // scale old α by (1 - src.a)
                            .alpha_blend = .add, // add the two
                            // Write to all RGBA channels
                            .enable_color_write_mask = false, // false = write all channels
                            .color_write_mask = .{ .red = true, .green = true, .blue = true, .alpha = true }, // (if you ever want R-only, etc.)
                            //Turn on blending
                            .enable_blend = true,
                        },
                    },
                },
                .depth_stencil_format = .depth24_unorm,
            },
            .depth_stencil_state = .{
                .compare = .less_or_equal,
                .enable_depth_test = true,
                .enable_depth_write = true,
            },
            .rasterizer_state = .{ .cull_mode = .back, .fill_mode = .fill },
        },
    );
    defer device.releaseGraphicsPipeline(pipeline);

    const vertex_buffer = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertices_byte_size,
    });
    defer device.releaseBuffer(vertex_buffer);

    const index_buffer = try device.createBuffer(.{
        .usage = .{ .index = true },
        .size = indices_byte_size,
    });
    defer device.releaseBuffer(index_buffer);

    // Create a transfer_buffer for Vertices and Indices
    const transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = vertices_byte_size + indices_byte_size,
    });
    defer device.releaseTransferBuffer(transfer_buffer);

    const vertex_index_transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
    @memcpy(vertex_index_transfer_buffer_mapped, std.mem.sliceAsBytes(vertices));
    @memcpy(vertex_index_transfer_buffer_mapped + vertices_byte_size, std.mem.sliceAsBytes(indices));
    device.unmapTransferBuffer(transfer_buffer);

    // Create a texture
    const texture = try device.createTexture(.{
        .usage = .{ .sampler = true },
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = image.width,
        .height = image.height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
    });
    defer device.releaseTexture(texture);

    // Create transfer_buffer for Texture
    const texture_transfer_buffer = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = pixels_byte_size,
    });
    defer device.releaseTransferBuffer(texture_transfer_buffer);
    const texture_transfer_buffer_mapped = try device.mapTransferBuffer(texture_transfer_buffer, false);

    @memcpy(texture_transfer_buffer_mapped, image.data);
    device.unmapTransferBuffer(texture_transfer_buffer);

    // Upload transfer data to the vertex buffer.
    const upload_cmd_buf = try device.acquireCommandBuffer();
    const copy_pass = upload_cmd_buf.beginCopyPass();

    copy_pass.uploadToBuffer(.{
        .transfer_buffer = transfer_buffer,
        .offset = 0,
    }, .{
        .buffer = vertex_buffer,
        .offset = 0,
        .size = vertices_byte_size,
    }, false);

    copy_pass.uploadToBuffer(.{
        .transfer_buffer = transfer_buffer,
        .offset = vertices_byte_size,
    }, .{
        .buffer = index_buffer,
        .offset = 0,
        .size = indices_byte_size,
    }, false);

    copy_pass.uploadToTexture(.{
        .offset = 0,
        .transfer_buffer = texture_transfer_buffer,
    }, .{
        .texture = texture,
        .width = image.width,
        .height = image.height,
        .depth = 1,
        .layer = 0,
    }, false);

    copy_pass.end();

    try upload_cmd_buf.submit();

    //--------------------------------------------------------------------
    //Vars
    var rotation: f32 = 0;
    var width: f32 = @floatFromInt(window_size.width);
    var height: f32 = @floatFromInt(window_size.height);
    var clear_color: [3]f32 = .{ 0.1, 0.2, 0.3 };

    const camera = Camera{
        .position = .{ 0.0, 0.0, -1.5, 0.0 },
        .target = .{ 0.0, 0.0, 0.0, 0.0 },
    };
    var present_mode: gpu.PresentMode = .vsync;
    // var pipline_primitive: gpu.PrimitiveType = .triangle_list;
    var paused = false;
    var rotation_speed: f32 = std.math.degreesToRadians(100);
    const proj_mat = zmath.perspectiveFovRh(std.math.degreesToRadians(70), width / height, 0.0001, 1000);

    var app_in_background = false;
    var needs_recreate_swapchain = false;
    while (true) {
        //Events
        var c_sdl_event: sdl3.c.SDL_Event = undefined;
        while (sdl3.c.SDL_PollEvent(&c_sdl_event)) {
            const guiConsumed = zgui_sdl.processEvent(&c_sdl_event);
            _ = guiConsumed;

            const io = zgui.io;
            if (io.getWantCaptureMouse() or io.getWantCaptureKeyboard() or io.getWantTextInput()) {
                continue;
            }

            switch (sdl3.events.Event.fromSdl(c_sdl_event)) {
                .quit => return,
                .key_down => |key| {
                    if (key.key) |k| {
                        switch (k) {
                            .space => paused = !paused,
                            .escape => return,
                            .ac_back => return,
                            .w => Camera.w_pressed = true,
                            .s => Camera.s_pressed = true,
                            .a => Camera.a_pressed = true,
                            .d => Camera.d_pressed = true,
                            else => {},
                        }
                    }
                },
                .key_up => |key| {
                    if (key.key) |k| {
                        switch (k) {
                            .w => Camera.w_pressed = false,
                            .s => Camera.s_pressed = false,
                            .a => Camera.a_pressed = false,
                            .d => Camera.d_pressed = false,
                            else => {},
                        }
                    }
                },
                .did_enter_background => {
                    app_in_background = true;
                },
                .did_enter_foreground => {
                    app_in_background = false;
                    needs_recreate_swapchain = true;
                },
                else => {},
            }
        }
        //Update
        window_size = try window.getSize();
        width = @floatFromInt(window_size.width);
        height = @floatFromInt(window_size.height);
        const delta_time = fps_manager.delay();

        if (!paused) rotation += rotation_speed * delta_time;
        const rot = zmath.rotationY(rotation);
        const trans = zmath.translation(0.0, 0.0, 0.0);
        const model_mat = zmath.mul(rot, trans);

        const view_mat = zmath.lookAtRh(camera.position, camera.target, zmath.Vec{ 0.0, 1.0, 0.0, 0.0 });
        const vp = zmath.mul(view_mat, proj_mat);
        const mvp = zmath.mul(model_mat, vp);

        const ubo = UBO{
            .mvp = mvp,
        };

        //Render
        //zgui
        if (!app_in_background) {
            if (needs_recreate_swapchain and !app_in_background) {
                device.releaseWindow(window);
                try device.claimWindow(window);
                zgui_sdl.deinit();
                zgui_sdl.init(window.value, .{
                    .device = device.value,
                    .color_target_format = @intFromEnum(device.getSwapchainTextureFormat(window)),
                    .msaa_samples = 0,
                });
                needs_recreate_swapchain = false;
            }
            zgui_sdl.newFrame(@intCast(window_size.width), @intCast(window_size.height), 1);

            const viewport_size = zgui.getMainViewport().getSize();
            zgui.setNextWindowSize(.{ .cond = .always, .w = viewport_size[0] / 4, .h = viewport_size[1] / 4 });
            zgui.setNextWindowBgAlpha(.{ .alpha = 0.1 });
            zgui.setNextWindowPos(.{ .cond = .always, .x = viewport_size[0] - viewport_size[0] / 4, .y = 0 });

            if (zgui.begin("Debug", .{ .flags = .{
                .no_resize = true,
                .no_collapse = true,
                .no_title_bar = true,
                .no_scrollbar = true,
                .no_docking = true,
                .no_nav_inputs = true,
            } })) {
                zgui.textUnformattedColored(.{ 0.1, 1, 0.1, 1 }, "Debug");
                zgui.text("GPU: {s}", .{driver_name});
                zgui.text("FPS: {d:.4}", .{fps_manager.getObservedFps()});
                zgui.text("Delta: {d:.4} ms", .{delta_time * 1000});
            }
            zgui.end();

            if (zgui.begin("Settings", .{})) {
                _ = zgui.colorEdit3("Clear Color", .{ .col = &clear_color });
            }

            if (zgui.comboFromEnum("Render Mode", &present_mode)) {
                try device.setSwapchainParameters(window, .sdr, present_mode);
            }

            // if (zgui.comboFromEnum("PrimitiveType", &pipline_primitive)) {
            //     device.releaseGraphicsPipeline(pipeline);
            //     pipeline = try setup_pipline(self.device, self.window, self.vertex_shader, self.fragment_shader, App.DEPTH_TEXTURE_FORMAT, pipline_primitive);
            // }

            if (!paused) {
                if (zgui.button("Pause", .{})) {
                    paused = true;
                }
            } else {
                if (zgui.button("Resume", .{})) {
                    paused = false;
                }
            }
            _ = zgui.sliderAngle("RotationSpeed", .{ .vrad = &rotation_speed, .deg_max = 180, .deg_min = -180 });
            zgui.end();

            const cmd_buff = try device.acquireCommandBuffer();
            sdl3.log.setAllPriorities(.err);
            const swap_chain = try cmd_buff.waitAndAcquireSwapchainTexture(window);
            sdl3.log.setAllPriorities(.info);

            zgui.render(); //--------------------Render Zgui----------------------

            if (swap_chain.texture) |tex| {
                cmd_buff.pushVertexUniformData(0, std.mem.asBytes(&ubo));

                // Start a render pass if the swapchain texture is available. Make sure to clear it.
                const render_pass = cmd_buff.beginRenderPass(&.{
                    sdl3.gpu.ColorTargetInfo{
                        .texture = tex,
                        .clear_color = .{ .r = clear_color[0], .g = clear_color[1], .b = clear_color[2], .a = 1 },
                        .load = .clear,
                    },
                }, .{
                    .texture = depth_texture,
                    .load = .clear,
                    .clear_depth = 1,
                    .store = .do_not_care,
                    .stencil_load = .load,
                    .stencil_store = .store,
                    .cycle = false,
                    .clear_stencil = 0,
                });
                render_pass.bindGraphicsPipeline(pipeline);
                render_pass.bindVertexBuffers(0, &.{gpu.BufferBinding{ .buffer = vertex_buffer, .offset = 0 }}); // TODO: Make it not hard coded
                render_pass.bindIndexBuffer(.{ .offset = 0, .buffer = index_buffer }, .indices_32bit);
                render_pass.bindFragmentSamplers(0, &.{gpu.TextureSamplerBinding{ .texture = texture, .sampler = sampler }}); // TODO: Make it not hard coded
                render_pass.drawIndexedPrimitives(@intCast(indices.len), 1, 0, 0, 0);
                render_pass.end();

                //----------------------Zgui RenderPass----------------------
                zgui_sdl.prepareDrawData(cmd_buff.value);
                const zgui_color_target = gpu.ColorTargetInfo{
                    .texture = tex,
                    .load = .load,
                };
                const zgui_render_pass = cmd_buff.beginRenderPass(&.{zgui_color_target}, null);
                zgui_sdl.renderDrawData(cmd_buff.value, zgui_render_pass.value, null);
                zgui_render_pass.end();
                //------------------------------------------------------------
            }

            // Finally submit the command buffer.
            try cmd_buff.submit();
        }
    }
}

fn zgui_style_init(window: sdl3.video.Window) !void {
    _ = zgui.io.addFontFromMemory(assets.files.fonts.@"Candara.ttf", std.math.floor(19 * try window.getDisplayScale()));
    zgui.io.setIniFilename(null);
    zgui.io.setConfigFlags(.{ .dock_enable = true });
    var style = zgui.getStyle();
    style.window_rounding = 12;
    style.child_rounding = 12;
    style.frame_rounding = 12;
    style.scrollbar_rounding = 12;
    style.grab_rounding = 12;
    style.tab_rounding = 12;
    style.popup_rounding = 12;
}

//-------------------------------------boilerplate
const builtin = @import("builtin");
const log = sdl3.log.log;
const is_android = builtin.abi.isAndroid();

/// This needs to be exported for Android builds
export fn SDL_main() callconv(.C) void {
    _ = std.start.callMain();
}
