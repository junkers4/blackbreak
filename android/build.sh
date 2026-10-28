#!/usr/bin/env bash
# Builds the BlackBreak APK from assembler: smali (Dalvik) and AArch64.
#   ./build.sh debug      -> build/blackbreak-debug.apk   (debuggable, signed with the debug key)
#   ./build.sh release    -> build/blackbreak-release.apk (signed with $ANDROID_KEYSTORE_FILE)
# Needs: the Android SDK (aapt2, zipalign, apksigner, android.jar) and NDK (clang), JDK 17+,
# and tools/lib (./gradlew :tools:fetchSmali). Version: VERSION_NAME and VERSION_CODE.
set -euo pipefail
cd "$(dirname "$0")"
kind=${1:-debug}
sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$(sed -n 's/^sdk.dir=//p' local.properties 2>/dev/null)}}
[ -d "$sdk" ] || { echo "no Android SDK: set ANDROID_HOME"; exit 1; }
bt=$(ls -d "$sdk"/build-tools/* | sort -V | tail -1)
platform=$sdk/platforms/android-35
[ -f "$platform/android.jar" ] || platform=$(ls -d "$sdk"/platforms/android-* | sort -V | tail -1)
ndk=$(ls -d "$sdk"/ndk/* | sort -V | tail -1)
clang=$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang
version_name=${VERSION_NAME:-0.0.0}
version_code=${VERSION_CODE:-1}
out=build/$kind
rm -rf "$out" && mkdir -p "$out/res" "$out/apk/lib/arm64-v8a"

# resources and the manifest
"$bt/aapt2" compile --dir app/src/main/res -o "$out/res.zip"
flags=()
[ "$kind" = debug ] && flags+=(--debug-mode)
"$bt/aapt2" link -o "$out/base.apk" -I "$platform/android.jar" --manifest app/src/main/AndroidManifest.xml \
    --min-sdk-version 26 --target-sdk-version 35 --version-code "$version_code" --version-name "$version_name" \
    "${flags[@]}" "$out/res.zip"

# the Dalvik code, from smali
smali_dirs=(app/src/main/smali)
[ "$kind" = debug ] && [ -d app/src/debug/smali ] && smali_dirs+=(app/src/debug/smali)
java -cp "tools/lib/*" com.android.tools.smali.smali.Main assemble --api 26 -o "$out/apk/classes.dex" "${smali_dirs[@]}"

# the pixel screens (the overlays and the app screen), compiled against compile-only stubs of
# the smali classes they call, and dexed as a second dex next to the smali one
rm -rf "$out/stubs" "$out/java" && mkdir -p "$out/stubs" "$out/java"
javac -nowarn -Xlint:-options --release 8 -cp "$platform/android.jar" -d "$out/stubs" stubs/io/github/junkers4/blackbreak/*.java
javac -nowarn -Xlint:-options --release 8 -cp "$platform/android.jar:$out/stubs" -d "$out/java" app/src/main/java/io/github/junkers4/blackbreak/*.java
"$bt/d8" --min-api 26 --output "$out/java" --lib "$platform/android.jar" "$out"/java/io/github/junkers4/blackbreak/*.class
mv "$out/java/classes.dex" "$out/apk/classes2.dex"

# the AArch64 core, no libc, 16 KB pages
"$clang" --target=aarch64-linux-android26 -shared -nostdlib -Wl,-z,max-page-size=16384 \
    -Wl,-soname,libblackbreak.so -o "$out/apk/lib/arm64-v8a/libblackbreak.so" \
    ../core/aarch64/core.S ../core/aarch64/controller.S ../core/aarch64/jni.S

# one zip: resources first, then code and library; stored uncompressed where the system maps them
cp "$out/base.apk" "$out/unsigned.apk"
(cd "$out/apk" && zip -q -X -0 ../unsigned.apk classes.dex classes2.dex && zip -q -X -0 -r ../unsigned.apk lib)
"$bt/zipalign" -f -p 4 "$out/unsigned.apk" "$out/aligned.apk"

if [ "$kind" = release ]; then
    : "${ANDROID_KEYSTORE_FILE:?set ANDROID_KEYSTORE_FILE}" "${ANDROID_KEYSTORE_PASSWORD:?set ANDROID_KEYSTORE_PASSWORD}"
    "$bt/apksigner" sign --ks "$ANDROID_KEYSTORE_FILE" --ks-key-alias blackbreak \
        --ks-pass env:ANDROID_KEYSTORE_PASSWORD --out "build/blackbreak-release.apk" "$out/aligned.apk"
    apk=build/blackbreak-release.apk
else
    ks=${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}
    if [ ! -f "$ks" ]; then
        mkdir -p "$(dirname "$ks")"
        keytool -genkeypair -keystore "$ks" -storepass android -keypass android -alias androiddebugkey \
            -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null
    fi
    "$bt/apksigner" sign --ks "$ks" --ks-key-alias androiddebugkey --ks-pass pass:android \
        --out "build/blackbreak-debug.apk" "$out/aligned.apk"
    apk=build/blackbreak-debug.apk
fi
"$bt/apksigner" verify "$apk"
echo "$apk: $(stat -c %s "$apk") bytes"
