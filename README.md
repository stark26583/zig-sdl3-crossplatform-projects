# Cross-Platform Zig SDL3 Projects

This is a cross-platform Zig build setup for SDL3 projects targeting **Desktop**, **Web (Emscripten)**, and **Android**.

⚠️ **Note:** This build system is **in development**, **not yet stable**, and relies on [Gota7's zig-sdl3](https://github.com/Gota7/zig-sdl3) for wrapper. It also uses a custom fork of [Castholm's SDL](https://github.com/castholm/SDL.git): [stark26583/SDL](https://github.com/stark26583/SDL.git) for build script. I am a beginner and don't know how to efficiently do them without having these many moving parts, please go through this repo and give feedback.

👉 Suggestions, pull requests for new platforms, and support for more SDL extensions are welcome!

---

## Build Commands

### 📦 Build for Desktop (Windows, Linux, etc.)

```bash
zig build [options] [project-name]
```

### 🌐 Build for Web (Emscripten)

```bash
source emsdk_env.sh
zig build -Dtarget=wasm64-emscripten [options] --sysroot "$(em-config CACHE)/sysroot" [project-name]
```

### 🤖 Build for Android

Set environment variables and run:

```bash
export JDK_HOME=/usr/lib/jvm/java-21-openjdk/
export ANDROID_HOME=/path/to/android/sdk

zig build -Dtarget=aarch64-linux-android [options] [project-name]
```

#### Example Android run script:

```bash
#!/bin/bash

export JDK_HOME=/usr/lib/jvm/java-21-openjdk/ 
export ANDROID_HOME=/path/to/android/sdk

set -e
arg1=$1
arg2=$2

zig build -Dtarget=aarch64-linux-android $arg2 $arg1

sudo $ANDROID_HOME/platform-tools/adb install zig-out/bin/$arg1-aarch64.apk
sudo $ANDROID_HOME/platform-tools/adb shell am start -S -W -n com.stark.$arg1/com.stark.$arg1.ZigSDLActivity
$ANDROID_HOME/platform-tools/adb logcat | grep "SDL/"
```

---

## 📂 Projects

All example projects are placed in the `projects/` or `gpu_projects/` folders.

Build any project by replacing `[project-name]` with its folder name.

---

## ✅ Requirements

* Zig 0.14+
* Emscripten SDK for Web builds
* Android SDK & NDK for Android builds
* Java JDK for Android signing

Enjoy portable SDL3 development!

