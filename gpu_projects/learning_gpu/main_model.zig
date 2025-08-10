const std = @import("std");
const sdl3 = @import("Cat");
const gpu = sdl3.gpu;
const assets = @import("assets");
const shaders = @import("shaders");

const zstbi = sdl3.zstbi;
const zgltf = sdl3.zgltf;
const zmath = sdl3.zmath;
const zgui = sdl3.zgui;
const zgui_sdl = zgui.backend;

const FpsManager = sdl3.FpsManager;

const SCREEN_WIDTH = if (builtin.cpu.arch.isAARCH64()) 2412 else 1280;
const SCREEN_HEIGHT = if (builtin.cpu.arch.isAARCH64()) 1080 else 780;

pub fn main() !void {
    defer sdl3.shutdown();
    sdl3.log.setAllPriorities(.info);

    try sdl3.hints.setWithPriority(.AndroidAllowRecreateActivity, "1", .Override);

    try sdl3.init(.{ .video = true });
    defer sdl3.quit(.{ .video = true });

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
    var gltf = zgltf.init(allocator);
    defer gltf.deinit();

    const window = try sdl3.video.Window.init("quad of my own?", SCREEN_WIDTH, SCREEN_HEIGHT, .{ .fullscreen = is_android });
    defer window.deinit();
    var window_size = try window.getSize();

    var fps_manager = FpsManager.init(.none);

    const device = try gpu.Device.init(.{ .spirv = true }, true, null);
    defer device.deinit();
    try device.claimWindow(window);
    defer device.releaseWindow(window);

    const driver_name = try device.getDriver();
    try zgui_style_init(window);

    zgui_sdl.init(window.value, .{
        .device = device.value,
        .color_target_format = @intFromEnum(device.getSwapchainTextureFormat(window)),
        .msaa_samples = 0,
    });
    defer zgui_sdl.deinit();

    //---------------------------GPU_Stuff--------------------------------
    const Vertex = packed struct {
        position: @Vector(3, f32),
        color: @Vector(4, u8),
        uv: @Vector(2, f32),
    };

    const UBO = struct {
        mvp: zmath.Mat,
    };

    const White: @Vector(4, u8) = .{ 255, 255, 255, 255 };
    const tint = White;

    const raw: []const u8 = assets.files.models.@"scifi_robot.glb";
    const size = raw.len;

    // 2) Allocate an aligned buffer for parsing
    //    allocAligned(T, count, alignment)
    var aligned_buf = try allocator.alignedAlloc(u8, 4, size);
    defer allocator.free(aligned_buf);

    // 3) Copy the embedded data into the aligned buffer
    @memcpy(aligned_buf[0..size], raw[0..size]);

    // 4) Cast it to the parser’s expected slice type
    const glb_buffer: []align(4) const u8 = aligned_buf[0..size];

    try gltf.parse(glb_buffer);

    std.log.info("Mesh count: {d}", .{gltf.data.meshes.items.len});
    if (gltf.data.meshes.items.len == 0) std.log.info("No mesh found in this model", .{});
    for (gltf.data.meshes.items) |mesh| {
        std.log.info("Mesh: {s}", .{mesh.name orelse "unknown"});
    }

    var vertices_arr = std.ArrayList(Vertex).init(allocator);
    defer vertices_arr.deinit();
    var indices_arr = std.ArrayList(u32).init(allocator);
    defer indices_arr.deinit();

    // Grab mesh 0
    for (gltf.data.meshes.items) |mesh| {
        // const mesh = gltf.data.meshes.items[0];
        for (mesh.primitives.items) |primitive| {
            const initial_vertex = vertices_arr.items.len;
            const ind_accessor = gltf.data.accessors.items[primitive.indices.?];
            var ind_it = ind_accessor.iterator(u32, &gltf, gltf.glb_binary.?);
            while (ind_it.next()) |i| {
                try indices_arr.append(i[0]);
            }
            for (primitive.attributes.items) |attribute| {
                switch (attribute) {
                    .position => |idx| {
                        const accessor = gltf.data.accessors.items[idx];
                        var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                        while (it.next()) |v| {
                            try vertices_arr.append(.{
                                .position = .{ v[0], v[1], v[2] },
                                .color = tint,
                                .uv = .{ 0.0, 0.0 },
                            });
                        }
                    },
                    .texcoord => |idx| {
                        const accessor = gltf.data.accessors.items[idx];
                        var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                        var i: usize = 0;
                        while (it.next()) |tc| : (i += 1) {
                            // write into the same slot we created above
                            vertices_arr.items[initial_vertex + i].uv = .{ tc[0], tc[1] };
                        }
                    },
                    else => {},
                }
            }
        }
    }

    std.log.info("▶️ Loaded mesh data: {d} vertices, {d} indices", .{ vertices_arr.items.len, indices_arr.items.len });
    if (indices_arr.items.len >= 3) {
        std.log.info("  First tri: {d}, {d}, {d}", .{ indices_arr.items[0], indices_arr.items[1], indices_arr.items[2] });
    }
    if (vertices_arr.items.len >= 1) {
        const v0 = vertices_arr.items[0];
        std.log.info("  v0.pos = ({d}, {d}, {d}), v0.uv = ({d}, {d})", .{ v0.position[0], v0.position[1], v0.position[2], v0.uv[0], v0.uv[1] });
    }

    // var image = try zstbi.Image.loadFromMemory(assets.files.images.@"colormap.png", 4);
    // defer image.deinit();
    var image: zstbi.Image = undefined;
    defer image.deinit();
    std.log.info("Image count: {d}", .{gltf.data.images.items.len});
    if (gltf.data.images.items.len == 0) std.log.info("No image found in this model", .{});
    const img = gltf.data.images.items[0];
    const image_name = img.name orelse "unknown";
    if (img.data) |data| {
        image = try zstbi.Image.loadFromMemory(data, 4);
        std.log.info("Image name: {s}", .{image_name});
        std.log.info("Image width: {d}", .{image.width});
        std.log.info("Image height: {d}", .{image.height});
        std.log.info("Image channels: {d}", .{image.num_components});
    }
    const pixels_byte_size = image.width * image.height * 4;

    const vertices = vertices_arr.items;
    const vertices_byte_size: u32 = @intCast(vertices_arr.items.len * @sizeOf(@TypeOf(vertices[0])));

    const indices = indices_arr.items;
    const indices_byte_size: u32 = @intCast(indices.len * @sizeOf(@TypeOf(indices[0])));

    std.debug.assert(indices.len % 3 == 0);

    const vertex_shader = try device.createShader(.{
        .code = shaders.files.@"shader.vertex.spirv",
        .entry_point = "main",
        .format = .{ .spirv = true },
        .stage = .vertex,
        .num_uniform_buffers = 1,
    });
    defer device.releaseShader(vertex_shader);

    const fragment_shader = try device.createShader(.{
        .code = shaders.files.@"shader.fragment.spirv",
        .entry_point = "main",
        .format = .{ .spirv = true },
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
            .rasterizer_state = .{ .cull_mode = .back },
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

    const transfer_buffer_mapped = try device.mapTransferBuffer(transfer_buffer, false);
    // Here we use the “pointer-to-array” trick to get a slice of exactly `total_size`
    const dst: []u8 = transfer_buffer_mapped[0 .. vertices_byte_size + indices_byte_size];

    // 3) Prepare your source slices as raw u8-views
    const vbytes: []const u8 = @ptrCast(vertices);
    const ibytes: []const u8 = @ptrCast(indices);
    @memcpy(dst[0..vertices_byte_size], vbytes);

    // 5) Copy your index data immediately after
    @memcpy(dst[vertices_byte_size .. vertices_byte_size + indices_byte_size], ibytes);
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
    var present_mode: gpu.PresentMode = .vsync;
    // var pipline_primitive: gpu.PrimitiveType = .triangle_list;
    var paused = false;

    var rotation_speed: f32 = std.math.degreesToRadians(100);
    const proj_mat = zmath.perspectiveFovRh(std.math.degreesToRadians(70), width / height, 0.0001, 1000);

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
                            else => {},
                        }
                    }
                },
                .finger_down => |f| {
                    _ = f;
                    paused = !paused;
                },
                else => {},
            }
        }
        //Update
        window_size = try window.getSize();
        width = @floatFromInt(window_size.width);
        height = @floatFromInt(window_size.height);
        fps_manager.tick();

        if (!paused) rotation += rotation_speed * fps_manager.getDelta();
        const rot = zmath.rotationY(rotation);
        const trans = zmath.translation(0.0, 0.0, -0.9);
        const model_mat = zmath.mul(rot, trans);
        const ubo = UBO{
            .mvp = zmath.mul(model_mat, proj_mat),
        };

        //Render
        //zgui
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
            zgui.text("FPS: {d:.4}", .{fps_manager.getFps()});
            zgui.text("Delta: {d:.4} ms", .{fps_manager.getDelta() * 1000});
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
const is_android = builtin.abi.isAndroid();

/// This needs to be exported for Android builds
export fn SDL_main() callconv(.C) void {
    _ = std.start.callMain();
}
