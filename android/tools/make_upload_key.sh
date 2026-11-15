#!/bin/sh
# Makes the Google Play upload key (android/upload-key.jks) and android/keystore.properties,
# which the release build reads. keytool asks for the password; both files stay out of git.
# Back up the key and password somewhere safe: Play needs this key for every update (Google can
# reset a lost upload key, but it takes days).
set -e
cd "$(dirname "$0")/.."
if [ -f upload-key.jks ]; then echo "upload-key.jks already exists; not replacing it."; exit 1; fi
printf "Choose a password for the upload key (at least 6 characters): "
stty -echo; read -r PASS; stty echo; echo
keytool -genkeypair -v -keystore upload-key.jks -alias upload -keyalg RSA -keysize 4096 \
  -validity 10000 -storepass "$PASS" -keypass "$PASS" -dname "CN=SooFunny, O=Soo X Intelligence LLC"
umask 077
cat > keystore.properties <<PROPS
storeFile=upload-key.jks
storePassword=$PASS
keyAlias=upload
keyPassword=$PASS
PROPS
echo "Made upload-key.jks and keystore.properties. Build with: ./gradlew :app:bundleRelease"
