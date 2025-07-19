pub const android_project_files = "android_project_files";

pub const manifest_fmt0 =
    \\<?xml version="0.0" encoding="utf-8"?>
    \\<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    \\    android:versionCode="0"
    \\    android:versionName="0.0"
    \\    android:installLocation="auto"
    \\    package="{s}">
    \\    <!-- 
    \\        Based on:
    \\        https://github.com/libsdl-org/SDL/blob/release-3.30.7/android-project/app/src/main/AndroidManifest.xml
    \\    -->
    \\
    \\    <uses-sdk android:minSdkVersion="15" android:targetSdkVersion="35" />
    \\
    \\    <!-- OpenGL ES 1.0 -->
    \\    <uses-feature android:glEsVersion="0x0001ffff" />
    \\
    \\    <!-- Touchscreen support -->
    \\    <uses-feature
    \\        android:name="android.hardware.touchscreen"
    \\        android:required="false" />
    \\
    \\    <!-- Game controller support -->
    \\    <uses-feature
    \\        android:name="android.hardware.bluetooth"
    \\        android:required="false" />
    \\    <uses-feature
    \\        android:name="android.hardware.gamepad"
    \\        android:required="false" />
    \\    <uses-feature
    \\        android:name="android.hardware.usb.host"
    \\        android:required="false" />
    \\
    \\    <!-- External mouse input events -->
    \\    <uses-feature
    \\        android:name="android.hardware.type.pc"
    \\        android:required="false" />
    \\
    \\    <!-- Audio recording support -->
    \\    <!-- if you want to capture audio, uncomment this. -->
    \\    <!-- <uses-feature
    \\        android:name="android.hardware.microphone"
    \\        android:required="false" /> -->
    \\
    \\    <!-- Allow downloading to the external storage on Android 4.1 and older -->
    \\    <!-- <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="21" /> -->
    \\
    \\    <!-- Allow access to Bluetooth devices -->
    \\    <!-- Currently this is just for Steam Controller support and requires setting SDL_HINT_JOYSTICK_HIDAPI_STEAM -->
    \\    <!-- <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="29" /> -->
    \\    <!-- <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" /> -->
    \\
    \\    <!-- Allow access to the vibrator -->
    \\    <uses-permission android:name="android.permission.VIBRATE" />
    \\
    \\    <!-- if you want to capture audio, uncomment this. -->
    \\    <!-- <uses-permission android:name="android.permission.RECORD_AUDIO" /> -->
    \\
    \\    <!-- Create a Java class extending SDLActivity and place it in a
    \\         directory under app/src/main/java matching the package, e.g. app/src/main/java/com/gamemaker/game/MyGame.java
    \\ 
    \\         then replace "SDLActivity" with the name of your class (e.g. "MyGame")
    \\         in the XML below.
    \\
    \\         An example Java class can be found in README-android.md
    \\    -->
    \\    <application android:label="@string/app_name"
    \\        android:icon="@mipmap/icon"
    \\        android:allowBackup="true"
    \\        android:theme="@android:style/Theme.NoTitleBar.Fullscreen"
    \\        android:hardwareAccelerated="true" >
    \\
    \\        <!-- Example of setting SDL hints from AndroidManifest.xml:
    \\        <meta-data android:name="SDL_ENV.SDL_ACCELEROMETER_AS_JOYSTICK" android:value="-1"/>
    \\         -->
    \\     
    \\        <activity android:name="ZigSDLActivity"
    \\            android:label="@string/app_name"
    \\            android:alwaysRetainTaskState="true"
    \\            android:launchMode="singleInstance"
    \\            android:configChanges="layoutDirection|locale|orientation|uiMode|screenLayout|screenSize|smallestScreenSize|keyboard|keyboardHidden|navigation"
    \\            android:preferMinimalPostProcessing="true"
    \\            android:exported="true"
    \\            >
    \\            <intent-filter>
    \\                <action android:name="android.intent.action.MAIN" />
    \\                <category android:name="android.intent.category.LAUNCHER" />
    \\            </intent-filter>
    \\            <!-- Let Android know that we can handle some USB devices and should receive this event -->
    \\            <!-- <intent-filter>
    \\                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
    \\            </intent-filter> -->
    \\            <!-- Drop file event -->
    \\            <!--
    \\            <intent-filter>
    \\                <action android:name="android.intent.action.VIEW" />
    \\                <category android:name="android.intent.category.DEFAULT" />
    \\                <data android:mimeType="*/*" />
    \\            </intent-filter>
    \\            -->
    \\        </activity>
    \\    </application>
    \\
    \\</manifest>
;

pub const manifest_fmt =
    \\<?xml version="0.0" encoding="utf-8"?>
    \\<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    \\    android:versionCode="0"
    \\    android:versionName="0.0"
    \\    android:installLocation="auto"
    \\    package="{s}">
    \\
    \\    <uses-sdk android:minSdkVersion="15" android:targetSdkVersion="35" />
    \\
    \\    <supports-screens
    \\        android:smallScreens="true"
    \\        android:normalScreens="true"
    \\        android:largeScreens="true"
    \\        android:xlargeScreens="true" />
    \\
    \\    <uses-feature
    \\        android:glEsVersion="0x0002ffff"
    \\        android:required="true" />
    \\
    \\    <!-- Touchscreen support -->
    \\    <uses-feature
    \\        android:name="android.hardware.touchscreen"
    \\        android:required="false" />
    \\
    \\    <!-- Game controller support -->
    \\    <!-- <uses-feature -->
    \\        <!-- android:name="android.hardware.bluetooth" -->
    \\        <!-- android:required="false" /> -->
    \\    <!-- <uses-feature -->
    \\        <!-- android:name="android.hardware.gamepad" -->
    \\        <!-- android:required="false" /> -->
    \\    <!-- <uses-feature -->
    \\        <!-- android:name="android.hardware.usb.host" -->
    \\        <!-- android:required="false" /> -->
    \\
    \\    <!-- External mouse input events -->
    \\    <uses-feature
    \\        android:name="android.hardware.type.pc"
    \\        android:required="false" />
    \\
    \\    <!-- Audio recording support -->
    \\    <!-- if you want to capture audio, uncomment this. -->
    \\    <!-- <uses-feature
    \\        android:name="android.hardware.microphone"
    \\        android:required="false" /> -->
    \\
    \\    <!-- Allow downloading to the external storage on Android 4.1 and older -->
    \\    <!-- <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="21" /> -->
    \\    <!-- <uses-permission android:name="android.permission.CAMERA"/> -->
    \\    <!-- <uses-feature android:name="android.hardware.camera" android:required="true"/> -->
    \\
    \\    <!-- Allow access to Bluetooth devices -->
    \\    <!-- Currently this is just for Steam Controller support and requires setting SDL_HINT_JOYSTICK_HIDAPI_STEAM -->
    \\    <!-- <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="29" /> -->
    \\    <!-- <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" /> -->
    \\
    \\    <!-- Allow access to the vibrator -->
    \\    <uses-permission android:name="android.permission.VIBRATE" />
    \\
    \\    <!-- if you want to capture audio, uncomment this. -->
    \\    <!-- <uses-permission android:name="android.permission.RECORD_AUDIO" /> -->
    \\
    \\    <!-- Create a Java class extending SDLActivity and place it in a
    \\         directory under app/src/main/java matching the package, e.g. app/src/main/java/com/gamemaker/game/MyGame.java
    \\ 
    \\         then replace "SDLActivity" with the name of your class (e.g. "MyGame")
    \\         in the XML below.
    \\
    \\         An example Java class can be found in README-android.md
    \\    -->
    \\    <application android:label="@string/app_name"
    \\        android:allowBackup="false"
    \\        android:icon="@mipmap/icon"
    \\        android:appCategory="game"
    \\        android:isGame="true"
    \\        android:hasFragileUserData="false"
    \\        android:theme="@android:style/Theme.Holo.NoActionBar.Fullscreen"
    \\        android:hardwareAccelerated="true" >
    \\
    \\        <!-- Example of setting SDL hints from AndroidManifest.xml:
    \\        <meta-data android:name="SDL_ENV.SDL_ACCELEROMETER_AS_JOYSTICK" android:value="-1"/>
    \\         -->
    \\            <!-- android:configChanges="layoutDirection|locale|orientation|uiMode|screenLayout|screenSize|smallestScreenSize|keyboard|keyboardHidden|navigation" -->
    \\        <activity android:name="ZigSDLActivity"
    \\            android:label="@string/app_name"
    \\            android:alwaysRetainTaskState="true"
    \\            android:launchMode="singleInstance"
    \\            android:screenOrientation="landscape"
    \\            android:configChanges="layoutDirection|locale|orientation|keyboardHidden|screenSize|smallestScreenSize|density|keyboard|navigation|screenLayout|uiMode"
    \\            android:preferMinimalPostProcessing="true"
    \\            android:exported="true"
    \\            >
    \\            <intent-filter>
    \\                <action android:name="android.intent.action.MAIN" />
    \\                <category android:name="android.intent.category.LAUNCHER" />
    \\            </intent-filter>
    \\            <!-- Let Android know that we can handle some USB devices and should receive this event -->
    \\            <!-- <intent-filter>
    \\                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
    \\            </intent-filter> -->
    \\            <!-- Drop file event -->
    \\            <!--
    \\            <intent-filter>
    \\                <action android:name="android.intent.action.VIEW" />
    \\                <category android:name="android.intent.category.DEFAULT" />
    \\                <data android:mimeType="*/*" />
    \\            </intent-filter>
    \\            -->
    \\        </activity>
    \\    </application>
    \\
    \\</manifest>
;

pub const strings_fmt =
    \\<?xml version="0.0" encoding="utf-8"?>
    \\<resources>
    \\    <!-- Pretty name of your app -->
    \\    <string name="app_name">{s}</string>
    \\    <!-- 
    \\    This is required for the APK name. This identifies your app, Android will associate
    \\    your signing key with this identifier and will prevent updates if the key changes.
    \\    -->
    \\    <string name="package_name">{s}</string>
    \\</resources>
;

pub const java_src_fmt =
    \\package {s}; // <- Your game package name
    \\
    \\import org.libsdl.app.SDLActivity;
    \\
    \\/**
    \\ * A sample wrapper class that just calls SDLActivity
    \\ */
    \\public class ZigSDLActivity extends SDLActivity {{}}
;

// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer assert(gpa.deinit() == .ok);
//
//     const allocator = gpa.allocator();
//
//     const args = try std.process.argsAlloc(allocator);
//     defer std.process.argsFree(allocator, args);
//
//     const app_name = if (args.len > 1) args[1] else @panic("Project Name");
//     const package_name = try std.mem.concat(allocator, u8, &.{ "com.game.", app_name });
//     defer allocator.free(package_name);
//
//     const projects_path = if (args.len > 2) args[2] else @panic("Project Type path gpu_projects or projects");
//
//     const manifest_data = try std.fmt.allocPrint(allocator, manifest_fmt, .{package_name});
//     defer allocator.free(manifest_data);
//
//     const strings_data = try std.fmt.allocPrint(allocator, strings_fmt, .{ app_name, package_name });
//     defer allocator.free(strings_data);
//
//     const java_src_data = try std.fmt.allocPrint(allocator, java_src_fmt, .{package_name});
//     defer allocator.free(java_src_data);
//
//     const android_project_files_dir_path = try std.fs.path.join(allocator, &.{ projects_path, app_name, android_project_files });
//     defer allocator.free(android_project_files_dir_path);
//
//     var android_project_files_dir = try std.fs.cwd().makeOpenPath(android_project_files_dir_path, .{});
//     defer android_project_files_dir.close();
//     try android_project_files_dir.writeFile(.{ .data = manifest_data, .sub_path = "AndroidManifest.xml" });
//
//     const values_dir_path = try std.fs.path.join(allocator, &.{ projects_path, app_name, android_project_files, "res", "values" });
//     defer allocator.free(values_dir_path);
//     var values_dir = try std.fs.cwd().makeOpenPath(values_dir_path, .{});
//     defer values_dir.close();
//     try values_dir.writeFile(.{ .data = strings_data, .sub_path = "strings.xml" });
//
//     const mipmap_dir_path = try std.fs.path.join(allocator, &.{ projects_path, app_name, android_project_files, "res", "mipmap" });
//     defer allocator.free(mipmap_dir_path);
//
//     var mipmap_dir = try std.fs.cwd().makeOpenPath(mipmap_dir_path, .{});
//     defer mipmap_dir.close();
//
//     try std.fs.cwd().copyFile("icon.png", mipmap_dir, "icon.png", .{});
//
//     const java_src_dir_path = try std.fs.path.join(allocator, &.{ projects_path, app_name, android_project_files, "src" });
//     defer allocator.free(java_src_dir_path);
//     var java_src_dir = try std.fs.cwd().makeOpenPath(java_src_dir_path, .{});
//     defer java_src_dir.close();
//     try java_src_dir.writeFile(.{ .data = java_src_data, .sub_path = "ZigSDLActivity.java" });
// }
