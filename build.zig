const std = @import("std");
const android = @import("android");
const assetpack = @import("assetpack");

pub fn build(b: *std.Build) !void {
    const root_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const android_targets = android.standardTargets(b, root_target);

    var root_target_single = [_]std.Build.ResolvedTarget{root_target};
    const targets: []std.Build.ResolvedTarget = if (android_targets.len == 0)
        root_target_single[0..]
    else
        android_targets;

    const projects = try makeProjects(b);
    defer {
        for (projects) |project| {
            b.allocator.free(project.name);
        }
        b.allocator.free(projects);
    }

    // TODO: add more targets into single apk
    // const android_module_single_target: ?*std.Build.Module = blk: {
    //     if (targets.len == 1 and root_target.result.abi.isAndroid()) {
    //         const android_dep = b.dependency("android", .{
    //             .optimize = optimize,
    //             .target = root_target,
    //         });
    //
    //         break :blk android_dep.module("android");
    //     } else break :blk null;
    // };

    // TODO: add sdl_image_dep after porting it to android
    // const sdl_image_dep = b.dependency("sdl_image", .{
    //     .target = root_target,
    //     .optimize = optimize,
    //     // TODO: Add options here...
    // });

    const zmath = b.dependency("zmath", .{});
    const zstbi = b.dependency("zstbi", .{});
    // const dvui = b.dependency("dvui", .{
    //     .target = root_target,
    //     .optimize = optimize,
    //     .backend = .sdl3,
    // });

    const cat_module = b.createModule(.{
        .root_source_file = b.path("src/sdl3.zig"),
        // .target = root_target,
    });
    // cat_module.addImport("dvui", dvui.module("dvui_sdl3"));
    const extension_options = b.addOptions();
    const main_callbacks = b.option(bool, "callbacks", "Enable SDL callbacks rather than use a main function") orelse false;
    extension_options.addOption(bool, "callbacks", main_callbacks);
    const sdl3_main = b.option(bool, "main", "Enable SDL main") orelse false;
    extension_options.addOption(bool, "main", sdl3_main);
    // TODO:
    //
    const ext_image = b.option(bool, "ext_image", "Enable SDL_image extension") orelse false;
    extension_options.addOption(bool, "image", ext_image);

    // TODO:
    // const ext_ttf = b.option(bool, "ext_ttf", "Enable SDL_ttf extension") orelse false;
    // extension_options.addOption(bool, "ttf", ext_ttf);

    // Linking zig-sdl to sdl3, makes the library much easier to use.
    cat_module.addOptions("extension_options", extension_options);
    // TODO:
    // if (ext_image) {
    const zstbi_mod = zstbi.module("root");
    cat_module.addImport("zstbi", zstbi_mod);
    cat_module.addImport("zmath", zmath.module("root"));
    // }

    // Linking zig-sdl to sdl3, makes the library much easier to use.

    for (projects) |project| {
        const assets_path = b.pathJoin(&.{ projects_path, project.name, "assets" });
        // If building with Android, initialize the tools / build

        // const generator_step: ?*std.Build.Step = blk: {
        //     if (root_target.result.abi.isAndroid()) break :blk try generator(b, projects_path, project.name) else break :blk null;
        // };
        if (root_target.result.abi.isAndroid()) try generator(b, projects_path, project.name);

        const android_apk: ?*android.APK = blk: {
            if (android_targets.len == 0) {
                break :blk null;
            }
            const android_tools = android.Tools.create(b, .{
                .api_level = .android15,
                .build_tools_version = "35.0.1",
                .ndk_version = "29.0.13113456",
            });
            const apk = android.APK.create(b, android_tools);

            const key_store_file = android_tools.createKeyStore(android.CreateKey.example());
            apk.setKeyStore(key_store_file);

            const android_project_files_path = b.pathJoin(&.{ projects_path, project.name, "android_project_files" });

            apk.setAndroidManifest(b.path(b.pathJoin(&.{ android_project_files_path, "AndroidManifest.xml" })));
            apk.addResourceDirectory(b.path(b.pathJoin(&.{ android_project_files_path, "res" })));

            // Add Java files
            apk.addJavaSourceFile(.{ .file = b.path(b.pathJoin(&.{ android_project_files_path, "src", "ZigSDLActivity.java" })) });

            // Add SDL2's Java files like SDL.java, SDLActivity.java, HIDDevice.java, etc
            const sdl_dep = b.dependency("sdl", .{
                .optimize = optimize,
                .target = android_targets[0],
            });
            const sdl_java_files = sdl_dep.namedWriteFiles("sdljava");
            for (sdl_java_files.files.items) |file| {
                apk.addJavaSourceFile(.{ .file = file.contents.copy });
            }
            break :blk apk;
        };

        const description = try std.mem.concat(b.allocator, u8, &.{ "Run the ", project.name, " project Natively" });
        defer b.allocator.free(description);

        const apk_description = try std.mem.concat(b.allocator, u8, &.{ "Build the ", project.name, " project for Android" });
        defer b.allocator.free(apk_description);

        const run = if (root_target.result.abi.isAndroid()) b.step(project.name, apk_description) else b.step(project.name, description);
        // if (generator_step) |generator_step_| run.dependOn(generator_step_);

        for (targets) |target| {
            const android_module: ?*std.Build.Module = blk: {
                if (targets.len > 1 and target.result.abi.isAndroid()) {
                    const android_dep = b.dependency("android", .{
                        .optimize = optimize,
                        .target = target,
                    });

                    break :blk android_dep.module("android");
                } else break :blk null;
            };
            var emscripten_system_include_path: ?std.Build.LazyPath = null;
            switch (target.result.os.tag) {
                .emscripten => {
                    if (b.sysroot) |sysroot| {
                        emscripten_system_include_path = .{ .cwd_relative = b.pathJoin(&.{ sysroot, "include" }) };
                    } else {
                        std.log.err("'--sysroot' is required when building for Emscripten", .{});
                        std.process.exit(1);
                    }
                },
                else => {},
            }

            const app_mod = b.createModule(.{
                .root_source_file = b.path(b.pathJoin(&.{ projects_path, project.name, main_file_name })),
                .target = target,
                .optimize = optimize,
                .link_libc = target.result.os.tag == .emscripten,
            });

            if (pathExists(assets_path)) {
                const assets_module = assetpack.pack(b, b.path(assets_path), .{});
                app_mod.addImport("assets", assets_module);
            }

            // if (android_module_single_target) |android_mod| {
            //     app_mod.addImport("android", android_mod);
            // }
            if (android_module) |android_mod| {
                const name = try std.mem.concat(b.allocator, u8, &.{ "android", target.result.cpu.arch.genericName() });
                defer b.allocator.free(name);

                app_mod.addImport(name, android_mod);
            }
            app_mod.addImport("Cat", cat_module);

            if (emscripten_system_include_path) |path| {
                cat_module.addSystemIncludePath(path);
                app_mod.addSystemIncludePath(path);
                zstbi_mod.addSystemIncludePath(path);
            }

            const library_optimize = if (!target.result.abi.isAndroid())
                optimize
            else
                // In Zig 0.14.0, for Android builds, make sure we build libraries with ReleaseSafe
                // otherwise we get errors relating to libubsan_rt.a getting RELOCATION errors
                // https://github.com/silbinarywolf/zig-android-sdk/issues/18
                if (optimize == .Debug) .ReleaseSafe else optimize;
            const sdl_dep = b.dependency("sdl", .{
                .target = target,
                .optimize = library_optimize,
                .lto = optimize != .Debug,
                .strip = true,
            });
            const sdl_lib = sdl_dep.artifact("SDL3");
            if (optimize != .Debug) reduce_size(sdl_lib, optimize);

            if (ext_image) {
                const sdl_image_dep = b.dependency("sdl_image", .{
                    .target = target,
                    .optimize = optimize,
                    // TODO: Add options here...
                });
                const sdl_image_module = sdl_image_dep.module("sdl_image");

                const sdl_image_lib = b.addLibrary(.{
                    .name = "SDL_image",
                    .version = .{ .major = 3, .minor = 2, .patch = 4 },
                    .linkage = .static,
                    .root_module = sdl_image_module,
                });
                if (target.result.abi.isAndroid()) {
                    sdl_image_lib.addIncludePath(sdl_dep.path("include"));
                    const android_tools = android.Tools.create(b, .{
                        .api_level = .android15,
                        .build_tools_version = "35.0.1",
                        .ndk_version = "29.0.13113456",
                    });
                    android_tools.setLibCFile(sdl_image_lib);
                }
                if (target.result.os.tag == .windows) {
                    sdl_image_lib.addIncludePath(sdl_dep.path("include"));
                }
                if (target.result.os.tag == .emscripten) {
                    sdl_image_lib.addIncludePath(emscripten_system_include_path.?);
                    sdl_image_lib.addIncludePath(sdl_dep.path("include"));
                }
                sdl_image_lib.linkLibC();
                b.installArtifact(sdl_image_lib);
                sdl_image_lib.installHeadersDirectory(sdl_image_dep.builder.dependency("SDL_image", .{}).path("include"), "", .{});

                // cat_module.addImport("SDL3_image", sdl_image_module);
                cat_module.linkLibrary(sdl_image_lib);
            }
            // TODO:
            // if (ext_ttf) {
            //     const sdl_ttf_dep = b.dependency("sdl_ttf", .{
            //         .target = target,
            //         .optimize = optimize,
            //         // TODO: Add options here...
            //     });
            //     const sdl_ttf_module = sdl_ttf_dep.module("sdl_ttf");
            //
            //     const sdl_ttf_lib = b.addLibrary(.{
            //         .name = "SDL_ttf",
            //         .version = .{ .major = 3, .minor = 2, .patch = 4 },
            //         .linkage = .static,
            //         .root_module = sdl_ttf_module,
            //     });
            //     if (target.result.abi.isAndroid()) {
            //         sdl_ttf_lib.addIncludePath(sdl_dep.path("include"));
            //         const android_tools = android.Tools.create(b, .{
            //             .api_level = .android15,
            //             .build_tools_version = "35.0.1",
            //             .ndk_version = "29.0.13113456",
            //         });
            //         android_tools.setLibCFile(sdl_ttf_lib);
            //     }
            //     if (target.result.os.tag == .emscripten) {
            //         sdl_ttf_lib.addIncludePath(emscripten_system_include_path.?);
            //         sdl_ttf_lib.addIncludePath(sdl_dep.path("include"));
            //     }
            //     sdl_ttf_lib.linkLibC();
            //     b.installArtifact(sdl_ttf_lib);
            //     sdl_ttf_lib.installHeadersDirectory(sdl_ttf_dep.builder.dependency("SDL_ttf", .{}).path("include"), "", .{});
            //
            //     // cat_module.addImport("SDL3_image", sdl_image_module);
            //     cat_module.linkLibrary(sdl_ttf_lib);
            // }

            if (target.result.os.tag == .emscripten) {
                // Build for the Web.
                cat_module.addIncludePath(sdl_dep.path("include"));
                app_mod.linkLibrary(sdl_lib);
                const app_lib = b.addLibrary(.{
                    .linkage = .static,
                    .name = project.name,
                    .root_module = app_mod,
                });
                app_lib.want_lto = optimize != .Debug;

                const run_emcc = b.addSystemCommand(&.{"emcc"});

                // Pass 'app_lib' and any static libraries it links with as input files.
                // 'app_lib.getCompileDependencies()' will always return 'app_lib' as the first element.
                for (app_lib.getCompileDependencies(false)) |lib| {
                    if (lib.isStaticLibrary()) {
                        run_emcc.addArtifactArg(lib);
                    }
                }

                if (target.result.cpu.arch == .wasm64) {
                    run_emcc.addArg("-sMEMORY64");
                }
                run_emcc.addArg("-sUSE_OFFSET_CONVERTER=1");

                run_emcc.addArgs(switch (optimize) {
                    .Debug => &.{
                        "-O0",
                        // Preserve DWARF debug information.
                        "-g",
                        // Use UBSan (full runtime).
                        "-fsanitize=undefined",
                    },
                    .ReleaseSafe => &.{
                        "-O3",
                        // Use UBSan (minimal runtime).
                        "-fsanitize=undefined",
                        "-fsanitize-minimal-runtime",
                    },
                    .ReleaseFast => &.{
                        "-O3",
                    },
                    .ReleaseSmall => &.{
                        "-Oz",
                    },
                });

                if (optimize != .Debug) {
                    // Perform link time optimization.
                    run_emcc.addArg("-flto");
                    // Minify JavaScript code.
                    run_emcc.addArgs(&.{ "--closure", "1" });
                }

                // Patch the default HTML shell.
                run_emcc.addArg("--pre-js");
                run_emcc.addFileArg(b.addWriteFiles().add("pre.js", (
                    // Display messages printed to stderr.
                    \\Module['printErr'] ??= Module['print'];
                    \\
                )));

                run_emcc.addArg("-o");

                const html_file = try std.mem.concat(b.allocator, u8, &.{ project.name, ".html" });
                defer b.allocator.free(html_file);

                const app_html = run_emcc.addOutputFileArg(html_file);

                const add_web_install_dir = b.addInstallDirectory(.{
                    .source_dir = app_html.dirname(),
                    .install_dir = .{ .custom = "www" },
                    .install_subdir = "",
                });

                const run_emrun = b.addSystemCommand(&.{"emrun"});
                run_emrun.addArg(b.pathJoin(&.{ b.install_path, "www", html_file }));
                if (b.args) |args| run_emrun.addArgs(args);
                run_emrun.step.dependOn(&add_web_install_dir.step);

                run.dependOn(&run_emrun.step);
            } else {
                // Build for desktop or Android.
                if (target.result.abi.isAndroid()) {
                    cat_module.linkLibrary(sdl_lib);

                    const apk_name = try std.mem.concat(b.allocator, u8, &.{ project.name, "-", @tagName(target.result.cpu.arch) });
                    defer b.allocator.free(apk_name);

                    var exe = b.addLibrary(.{
                        .name = apk_name,
                        .root_module = app_mod,
                        .linkage = .dynamic,
                    });
                    if (optimize != .Debug) reduce_size(exe, optimize);

                    exe.linkLibrary(sdl_lib);

                    const apk: *android.APK = android_apk orelse @panic("Android APK should be initialized");

                    apk.addArtifact(exe);

                    if (android_apk) |apk_| {
                        const apk_install = apk_.addInstallApk();
                        run.dependOn(&apk_install.step);
                    }
                } else if (target.result.os.tag == .windows) {
                    cat_module.addIncludePath(sdl_dep.path("include"));
                    const app_exe = b.addExecutable(.{
                        .name = project.name,
                        .root_module = app_mod,
                        .strip = optimize == .ReleaseSafe or optimize == .ReleaseFast or optimize == .ReleaseSmall,
                    });
                    app_exe.want_lto = optimize != .Debug;

                    app_exe.addIncludePath(sdl_dep.path("include"));
                    // app_exe.addLibraryPath(sdl_dep.path("lib"));
                    app_exe.linkLibrary(sdl_lib);

                    if (optimize != .Debug) reduce_size(app_exe, optimize);
                    const install_step = b.addInstallArtifact(app_exe, .{});

                    run.dependOn(&install_step.step);
                } else {
                    app_mod.linkLibrary(sdl_lib);

                    const app_exe = b.addExecutable(.{
                        .name = project.name,
                        .root_module = app_mod,
                        .strip = optimize == .ReleaseSafe or optimize == .ReleaseFast or optimize == .ReleaseSmall,
                    });
                    app_exe.want_lto = optimize != .Debug;

                    if (optimize != .Debug) reduce_size(app_exe, optimize);

                    b.installArtifact(app_exe);

                    const run_app = b.addRunArtifact(app_exe);
                    if (b.args) |args| run_app.addArgs(args);
                    // run_app.step.dependOn(b.getInstallStep());
                    // run_app.step.dependOn(app_exe.step);

                    run.dependOn(&run_app.step);
                }
            }
        }
    }

    const gpu_projects = try makeGpuProjects(b);
    defer {
        for (gpu_projects) |project| {
            b.allocator.free(project.name);
        }
        b.allocator.free(gpu_projects);
    }

    for (gpu_projects) |project| {
        if (std.mem.containsAtLeast(u8, project.name, 1, "validation")) continue;
        // const generator_step: ?*std.Build.Step = blk: {
        //     if (root_target.result.abi.isAndroid()) break :blk try generator(b, gpu_projects_path, project.name) else break :blk null;
        // };

        if (root_target.result.abi.isAndroid()) try generator(b, gpu_projects_path, project.name);

        const shaders_path = b.pathJoin(&.{ gpu_projects_path, project.name, "shaders" });
        // If building with Android, initialize the tools / build
        const android_apk: ?*android.APK = blk: {
            if (android_targets.len == 0) {
                break :blk null;
            }
            const android_tools = android.Tools.create(b, .{
                .api_level = .android15,
                .build_tools_version = "35.0.1",
                .ndk_version = "29.0.13113456",
            });
            const apk = android.APK.create(b, android_tools);

            const key_store_file = android_tools.createKeyStore(android.CreateKey.example());
            apk.setKeyStore(key_store_file);
            const android_project_files_path = b.pathJoin(&.{ gpu_projects_path, project.name, "android_project_files" });

            apk.setAndroidManifest(b.path(b.pathJoin(&.{ android_project_files_path, "AndroidManifest.xml" })));
            apk.addResourceDirectory(b.path(b.pathJoin(&.{ android_project_files_path, "res" })));

            // Add Java files
            apk.addJavaSourceFile(.{ .file = b.path(b.pathJoin(&.{ android_project_files_path, "src", "ZigSDLActivity.java" })) });

            // Add SDL2's Java files like SDL.java, SDLActivity.java, HIDDevice.java, etc
            const sdl_dep = b.dependency("sdl", .{
                .optimize = optimize,
                .target = android_targets[0],
            });
            const sdl_java_files = sdl_dep.namedWriteFiles("sdljava");
            for (sdl_java_files.files.items) |file| {
                apk.addJavaSourceFile(.{ .file = file.contents.copy });
            }
            break :blk apk;
        };

        const description = try std.mem.concat(b.allocator, u8, &.{ "Run the GPU project ", project.name, " Natively" });
        defer b.allocator.free(description);

        const apk_description = try std.mem.concat(b.allocator, u8, &.{ "Build the GPU project ", project.name, " for Android" });
        defer b.allocator.free(apk_description);

        const run = if (root_target.result.abi.isAndroid()) b.step(project.name, apk_description) else b.step(project.name, description);
        // if (generator_step) |generator_step_| run.dependOn(generator_step_);

        for (targets) |target| {
            const android_module: ?*std.Build.Module = blk: {
                if (targets.len > 1 and target.result.abi.isAndroid()) {
                    const android_dep = b.dependency("android", .{
                        .optimize = optimize,
                        .target = target,
                    });

                    break :blk android_dep.module("android");
                } else break :blk null;
            };
            // var emscripten_system_include_path: ?std.Build.LazyPath = null;
            // switch (target.result.os.tag) {
            //     .emscripten => {
            //         @panic("GPU not implemented for web.");
            //         // if (b.sysroot) |sysroot| {
            //         //     emscripten_system_include_path = .{ .cwd_relative = b.pathJoin(&.{ sysroot, "include" }) };
            //         // } else {
            //         //     std.log.err("'--sysroot' is required when building for Emscripten", .{});
            //         //     std.process.exit(1);
            //         // }
            //     },
            //     else => {},
            // }

            const app_mod = b.createModule(.{
                .root_source_file = b.path(b.pathJoin(&.{ gpu_projects_path, project.name, main_file_name })),
                .target = target,
                .optimize = optimize,
                // .link_libc = target.result.os.tag == .emscripten,
            });

            try compileShaders(b, app_mod, shaders_path);
            // if (android_module_single_target) |android_mod| {
            //     app_mod.addImport("android", android_mod);
            // }
            if (android_module) |android_mod| {
                const name = try std.mem.concat(b.allocator, u8, &.{ "android", target.result.cpu.arch.genericName() });
                defer b.allocator.free(name);

                app_mod.addImport(name, android_mod);
            }
            app_mod.addImport("Cat", cat_module);

            // if (emscripten_system_include_path) |path| {
            //     cat_module.addSystemIncludePath(path);
            //     app_mod.addSystemIncludePath(path);
            // }

            const library_optimize = if (!target.result.abi.isAndroid())
                optimize
            else
                // In Zig 0.14.0, for Android builds, make sure we build libraries with ReleaseSafe
                // otherwise we get errors relating to libubsan_rt.a getting RELOCATION errors
                // https://github.com/silbinarywolf/zig-android-sdk/issues/18
                if (optimize == .Debug) .ReleaseSafe else optimize;
            const sdl_dep = b.dependency("sdl", .{
                .target = target,
                .optimize = library_optimize,
                .lto = optimize != .Debug,
                .strip = true,
                .pic = true,
            });

            if (ext_image) {
                const sdl_image_dep = b.dependency("sdl_image", .{
                    .target = target,
                    .optimize = optimize,
                    // TODO: Add options here...
                });
                const sdl_image_module = sdl_image_dep.module("sdl_image");

                const sdl_image_lib = b.addLibrary(.{
                    .name = "SDL_image",
                    .version = .{ .major = 3, .minor = 2, .patch = 4 },
                    .linkage = .static,
                    .root_module = sdl_image_module,
                });
                if (target.result.abi.isAndroid()) {
                    sdl_image_lib.addIncludePath(sdl_dep.path("include"));
                    const android_tools = android.Tools.create(b, .{
                        .api_level = .android15,
                        .build_tools_version = "35.0.1",
                        .ndk_version = "29.0.13113456",
                    });
                    android_tools.setLibCFile(sdl_image_lib);
                }
                sdl_image_lib.linkLibC();
                b.installArtifact(sdl_image_lib);
                sdl_image_lib.installHeadersDirectory(sdl_image_dep.builder.dependency("SDL_image", .{}).path("include"), "", .{});

                // cat_module.addImport("SDL3_image", sdl_image_module);
                cat_module.linkLibrary(sdl_image_lib);
            }

            // TODO:
            // if (ext_ttf) {
            //     const sdl_ttf_dep = b.dependency("sdl_ttf", .{
            //         .target = target,
            //         .optimize = optimize,
            //         // TODO: Add options here...
            //     });
            //     const sdl_ttf_module = sdl_ttf_dep.module("sdl_ttf");
            //
            //     const sdl_ttf_lib = b.addLibrary(.{
            //         .name = "SDL_ttf",
            //         .version = .{ .major = 3, .minor = 2, .patch = 4 },
            //         .linkage = .static,
            //         .root_module = sdl_ttf_module,
            //     });
            //     if (target.result.abi.isAndroid()) {
            //         sdl_ttf_lib.addIncludePath(sdl_dep.path("include"));
            //         const android_tools = android.Tools.create(b, .{
            //             .api_level = .android15,
            //             .build_tools_version = "35.0.1",
            //             .ndk_version = "29.0.13113456",
            //         });
            //         android_tools.setLibCFile(sdl_ttf_lib);
            //     }
            //     sdl_ttf_lib.linkLibC();
            //     b.installArtifact(sdl_ttf_lib);
            //     sdl_ttf_lib.installHeadersDirectory(sdl_ttf_dep.builder.dependency("SDL_ttf", .{}).path("include"), "", .{});
            //
            //     // cat_module.addImport("SDL3_image", sdl_image_module);
            //     cat_module.linkLibrary(sdl_ttf_lib);
            // }

            // Build for desktop or Android.
            if (target.result.abi.isAndroid()) {
                const sdl_lib = sdl_dep.artifact("SDL3");
                if (optimize != .Debug) reduce_size(sdl_lib, optimize);
                cat_module.linkLibrary(sdl_lib);

                const apk_name = try std.mem.concat(b.allocator, u8, &.{ project.name, "-", @tagName(target.result.cpu.arch) });
                defer b.allocator.free(apk_name);

                var exe = b.addLibrary(.{
                    .name = apk_name,
                    .root_module = app_mod,
                    .linkage = .dynamic,
                });
                // exe.addLibraryPath(b.path("gpu_projects/valdation_layers/arm64-v8a/"));
                // exe.linkSystemLibrary("VkLayer_khronos_validation");
                if (optimize != .Debug) reduce_size(exe, optimize);

                exe.linkLibrary(sdl_lib);

                const apk: *android.APK = android_apk orelse @panic("Android APK should be initialized");

                apk.addArtifact(exe);

                if (android_apk) |apk_| {
                    const apk_install = apk_.addInstallApk();
                    run.dependOn(&apk_install.step);
                }
            } else {
                const sdl_lib = sdl_dep.artifact("SDL3");
                if (optimize != .Debug) reduce_size(sdl_lib, optimize);

                app_mod.linkLibrary(sdl_lib);

                const app_exe = b.addExecutable(.{
                    .name = project.name,
                    .root_module = app_mod,
                    .strip = optimize == .ReleaseSafe or optimize == .ReleaseFast or optimize == .ReleaseSmall,
                });
                app_exe.want_lto = optimize != .Debug;
                if (optimize != .Debug) reduce_size(app_exe, optimize);

                b.installArtifact(app_exe);

                const run_app = b.addRunArtifact(app_exe);
                if (b.args) |args| run_app.addArgs(args);
                // run_app.step.dependOn(b.getInstallStep());
                // run_app.step.dependOn(app_exe.step);

                run.dependOn(&run_app.step);
            }
        }
    }
}

const projects_path = "projects/";
const gpu_projects_path = "gpu_projects/";
const main_file_name = "/main.zig";

const Project = struct {
    name: []const u8,
};

fn makeProjects(b: *std.Build) ![]Project {
    var projects = std.ArrayList(Project).init(b.allocator);
    defer projects.deinit();

    var projects_dir = try std.fs.cwd().openDir(projects_path, .{ .iterate = true });
    defer projects_dir.close();

    var projects_dir_iterator = projects_dir.iterate();

    while (try projects_dir_iterator.next()) |entry| {
        if (entry.kind == .directory) {
            const proj_name = entry.name;

            try projects.append(.{
                .name = b.dupe(proj_name),
            });
        }
    }
    return try projects.toOwnedSlice();
}

fn makeGpuProjects(b: *std.Build) ![]Project {
    var projects = std.ArrayList(Project).init(b.allocator);
    defer projects.deinit();

    var projects_dir = try std.fs.cwd().openDir(gpu_projects_path, .{ .iterate = true });
    defer projects_dir.close();

    var projects_dir_iterator = projects_dir.iterate();

    while (try projects_dir_iterator.next()) |entry| {
        if (entry.kind == .directory) {
            const proj_name = entry.name;

            try projects.append(.{
                .name = b.dupe(proj_name),
            });
        }
    }
    return try projects.toOwnedSlice();
}

fn compileShader(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    module: *std.Build.Module,
    path: []const u8,
    out_name: []const u8,
) void {
    const shader = b.addObject(.{
        .name = out_name,
        .root_source_file = b.path(path),
        .target = target,
        .optimize = .ReleaseFast,
        .strip = true,
        .use_llvm = false,
        .use_lld = false,
    });
    module.addAnonymousImport(out_name, .{
        .root_source_file = shader.getEmittedBin(),
    });
}

fn compileShaders(b: *std.Build, module: *std.Build.Module, shaders_path: []const u8) !void {
    if (pathExists(shaders_path)) {
        const vulkan12_target = b.resolveTargetQuery(.{
            .cpu_arch = .spirv64,
            .cpu_model = .{ .explicit = &std.Target.spirv.cpu.vulkan_v1_2 },
            .cpu_features_add = std.Target.spirv.featureSet(&.{.int64}),
            .os_tag = .vulkan,
            .ofmt = .spirv,
        });
        // Compile shaders. Something about this feels hacky though with how the paths are gotten with cwd rather than the build system paths.
        var shader_dir = try std.fs.cwd().openDir(shaders_path, .{ .iterate = true });
        defer shader_dir.close();
        var shader_dir_walker = try shader_dir.walk(b.allocator);
        defer shader_dir_walker.deinit();
        while (try shader_dir_walker.next()) |shader| {
            if (shader.kind != .file or !(std.mem.endsWith(u8, shader.basename, ".vert.zig") or std.mem.endsWith(u8, shader.basename, ".frag.zig")))
                continue;
            const spv_name = try std.mem.replaceOwned(u8, b.allocator, shader.basename, ".zig", ".spv");
            defer b.allocator.free(spv_name);

            const shader_path = b.pathJoin(&.{ shaders_path, shader.basename });
            compileShader(b, vulkan12_target, module, shader_path, spv_name);
        }
    }
}

const manifest_fmt = @embedFile("src/android_project_files_generator/AndroidManifest.xml");
const strings_fmt = @embedFile("src/android_project_files_generator/strings.xml");
const java_src_fmt = @embedFile("src/android_project_files_generator/ZigSDLActivity.java");
const android_project_files = "android_project_files";

fn generator(b: *std.Build, project_type: []const u8, project_name: []const u8) !void {
    const package_name = try std.mem.concat(b.allocator, u8, &.{ "com.stark.", project_name });
    defer b.allocator.free(package_name);

    const manifest_data = try std.fmt.allocPrint(b.allocator, manifest_fmt, .{package_name});
    defer b.allocator.free(manifest_data);

    const strings_data = try std.fmt.allocPrint(b.allocator, strings_fmt, .{ project_name, package_name });
    defer b.allocator.free(strings_data);

    const java_src_data = try std.fmt.allocPrint(b.allocator, java_src_fmt, .{package_name});
    defer b.allocator.free(java_src_data);

    const android_project_files_dir_path = b.pathJoin(&.{ project_type, project_name, android_project_files });

    if (!pathExists(android_project_files_dir_path)) {
        var android_project_files_dir = try std.fs.cwd().makeOpenPath(android_project_files_dir_path, .{});
        defer android_project_files_dir.close();
        try android_project_files_dir.writeFile(.{ .data = manifest_data, .sub_path = "AndroidManifest.xml" });

        const values_dir_path = b.pathJoin(&.{ project_type, project_name, android_project_files, "res", "values" });
        var values_dir = try std.fs.cwd().makeOpenPath(values_dir_path, .{});
        defer values_dir.close();
        try values_dir.writeFile(.{ .data = strings_data, .sub_path = "strings.xml" });

        const mipmap_dir_path = b.pathJoin(&.{ project_type, project_name, android_project_files, "res", "mipmap" });

        var mipmap_dir = try std.fs.cwd().makeOpenPath(mipmap_dir_path, .{});
        defer mipmap_dir.close();

        try std.fs.cwd().copyFile("icon.png", mipmap_dir, "icon.png", .{});

        const java_src_dir_path = b.pathJoin(&.{ project_type, project_name, android_project_files, "src" });
        var java_src_dir = try std.fs.cwd().makeOpenPath(java_src_dir_path, .{});
        defer java_src_dir.close();
        try java_src_dir.writeFile(.{ .data = java_src_data, .sub_path = "ZigSDLActivity.java" });
    }
}

pub fn pathExists(path: []const u8) bool {
    const fs = std.fs;
    // Attempt to access for reading:
    var exist: bool = undefined;
    _ = fs.cwd().access(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            exist = false;
            return exist;
        },
        else => {},
    };

    exist = true;
    return exist;
}

fn reduce_size(compile: *std.Build.Step.Compile, optimize: std.builtin.OptimizeMode) void {
    compile.root_module.strip = optimize != .Debug;
    compile.root_module.sanitize_c = optimize == .Debug;
    compile.root_module.sanitize_thread = optimize == .Debug;
    compile.root_module.unwind_tables = if (optimize != .Debug) .none else compile.root_module.unwind_tables;
    compile.want_lto = optimize != .Debug;
    compile.link_gc_sections = optimize != .Debug;
    compile.bundle_ubsan_rt = optimize == .Debug;
    compile.dead_strip_dylibs = optimize != .Debug;
    // compile.bundle_compiler_rt = optimize == .Debug;
}
