#!/bin/sh
# Makes the Google Play upload key (android/upload-key.jks) and android/keystore.properties,
# which the release build reads. keytool asks for the password; both files stay out of git.
# Back up the key and password somewhere safe: Play needs this key for every update (Google can
# reset a lost upload key, but it takes days).
set -e
cd "$(dirname "$0")/.."
if [ -f upload-key.jks ]; then echo "upload-key.jks already exists; not replacing it."; exit 1; fi

# macOS's /usr/bin/keytool is only a stub without a JDK, so find a real one.
KEYTOOL=""
for home in "$JAVA_HOME" /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home "$(/usr/libexec/java_home 2>/dev/null)" \
  "/Applications/Android Studio.app/Contents/jbr/Contents/Home"; do
  if [ -n "$home" ] && [ -x "$home/bin/keytool" ]; then KEYTOOL="$home/bin/keytool"; break; fi
done
if [ -z "$KEYTOOL" ]; then echo "No JDK found. Install one (brew install openjdk@21) or set JAVA_HOME."; exit 1; fi

printf "Choose a password for the upload key (at least 6 characters): "
stty -echo; read -r PASS; stty echo; echo
printf "Type it again: "
stty -echo; read -r PASS2; stty echo; echo
if [ "$PASS" != "$PASS2" ]; then echo "The passwords don't match; nothing was made."; exit 1; fi
if [ ${#PASS} -lt 6 ]; then echo "The password must be at least 6 characters; nothing was made."; exit 1; fi
"$KEYTOOL" -genkeypair -v -keystore upload-key.jks -alias upload -keyalg RSA -keysize 4096 \
  -validity 10000 -storepass "$PASS" -keypass "$PASS" -dname "CN=SooFunny, O=Soo X Intelligence LLC"
umask 077
cat > keystore.properties <<PROPS
storeFile=upload-key.jks
storePassword=$PASS
keyAlias=upload
keyPassword=$PASS
PROPS
echo "Made upload-key.jks and keystore.properties. Build with: ./gradlew :app:bundleRelease"
