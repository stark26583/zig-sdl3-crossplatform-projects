#!/bin/bash

export JDK_HOME=/usr/lib/jvm/java-21-openjdk/ 
export ANDROID_HOME=/home/stark/Software/Android/Sdk/ 

set -e
arg1=$1
arg2=$2

zig build -Dtarget=x86_64-linux-android $arg2 $arg1

waydroid app install zig-out/bin/$arg1-x86_64.apk
# waydroid app launch com.stark.$arg1
sudo waydroid logcat | grep "SDL/"

