#!/bin/bash

export JDK_HOME=/usr/lib/jvm/java-21-openjdk/ 
export ANDROID_HOME=/home/stark/Software/Android/Sdk/ 

set -e

zig build -Dtarget=aarch64-linux-android $@
n=$#
last_arg=${!n}

# sudo /home/stark/Software/Android/Sdk/platform-tools/adb uninstall "com.stark.$arg1"
sudo /home/stark/Software/Android/Sdk/platform-tools/adb install zig-out/bin/$last_arg-aarch64.apk
sudo /home/stark/Software/Android/Sdk/platform-tools/adb shell am start -S -W -n com.stark.$last_arg/com.stark.$last_arg.ZigSDLActivity
echo "----------------------Started $last_arg----------------------"
/home/stark/Software/Android/Sdk/platform-tools/adb logcat | grep -E "SDL/|com.stark.$last_arg:"
echo "----------------------Ended $last_arg----------------------"
