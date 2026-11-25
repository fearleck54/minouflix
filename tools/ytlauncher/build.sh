#!/bin/bash
# compile l'APK sans gradle : aapt2 + javac + d8 + apksigner (clé de signature jetable, installation à la main)
set -e
cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
BT="$SDK/build-tools/$(ls "$SDK/build-tools" | sort -V | tail -1)"
JAR="$SDK/platforms/$(ls "$SDK/platforms" | sort -V | tail -1)/android.jar"
rm -rf out && mkdir -p out/cls
"$BT/aapt2" compile --dir res -o out/res.zip
"$BT/aapt2" link -o out/base.apk -I "$JAR" --manifest AndroidManifest.xml --min-sdk-version 21 --target-sdk-version 33 --version-code 1 --version-name 1.0 out/res.zip
javac --release 8 -cp "$JAR" -d out/cls $(find src -name '*.java')
"$BT/d8" --lib "$JAR" --output out $(find out/cls -name '*.class')
(cd out && zip -q base.apk classes.dex)
"$BT/zipalign" -f 4 out/base.apk out/aligned.apk
keytool -genkeypair -keystore out/ks.jks -storepass android -keypass android -alias k -keyalg RSA -keysize 2048 -validity 36500 -dname "CN=YouTube launcher" >/dev/null 2>&1
"$BT/apksigner" sign --ks out/ks.jks --ks-pass pass:android --out out/YouTube-launcher.apk out/aligned.apk
ls -la out/YouTube-launcher.apk
