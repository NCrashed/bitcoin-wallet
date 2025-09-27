
# Script to sign Bitcoin Wallet APK for personal use

echo "Bitcoin Wallet APK Signing Script"
echo "================================="
echo

# Check if keytool and apksigner are available
if ! command -v keytool &> /dev/null; then
    echo "Error: keytool not found. Make sure Java is installed."
    exit 1
fi

if ! command -v apksigner &> /dev/null && ! [ -f "$ANDROID_HOME/build-tools/35.0.0/apksigner" ]; then
    echo "Error: apksigner not found. Make sure Android SDK is properly set up."
    exit 1
fi

# Set apksigner path
APKSIGNER="$ANDROID_HOME/build-tools/35.0.0/apksigner"

# Keystore configuration
KEYSTORE_DIR="$HOME/.android-keys"
KEYSTORE_FILE="$KEYSTORE_DIR/bitcoin-wallet-keystore.jks"
KEY_ALIAS="bitcoin-wallet"

# Create keystore directory if it doesn't exist
mkdir -p "$KEYSTORE_DIR"

# Check if keystore already exists
if [ ! -f "$KEYSTORE_FILE" ]; then
    echo "Creating new keystore..."
    echo "You'll be asked to set a password and provide some information."
    echo "Remember your password - you'll need it to sign APKs!"
    echo
    
    keytool -genkey -v \
        -keystore "$KEYSTORE_FILE" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass "changeme" \
        -keypass "changeme" \
        -dname "CN=Bitcoin Wallet User, OU=Personal, O=Personal, L=Unknown, ST=Unknown, C=US"
    
    echo
    echo "Keystore created at: $KEYSTORE_FILE"
    echo "IMPORTANT: The default password is 'changeme'. You should change this!"
    echo "To change password, run: keytool -storepasswd -keystore $KEYSTORE_FILE"
    echo
else
    echo "Using existing keystore at: $KEYSTORE_FILE"
fi

# Find unsigned APK
UNSIGNED_APK="wallet/build/outputs/apk/prod/release/bitcoin-wallet-prod-release-unsigned.apk"
SIGNED_APK="wallet/build/outputs/apk/prod/release/bitcoin-wallet-prod-release-signed.apk"

if [ ! -f "$UNSIGNED_APK" ]; then
    echo "Error: Unsigned APK not found at $UNSIGNED_APK"
    echo "Please build it first with: gradle :wallet:assembleProdRelease -x test"
    exit 1
fi

echo
echo "Signing APK..."
echo "Source: $UNSIGNED_APK"
echo "Output: $SIGNED_APK"
echo

# Sign the APK
"$APKSIGNER" sign \
    --ks "$KEYSTORE_FILE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass pass:changeme \
    --key-pass pass:changeme \
    --out "$SIGNED_APK" \
    "$UNSIGNED_APK"

if [ $? -eq 0 ]; then
    echo "Success! Signed APK created at:"
    echo "$SIGNED_APK"
    echo
    echo "You can now install it on your device with:"
    echo "adb install $SIGNED_APK"
    
    # Verify the signature
    echo
    echo "Verifying signature..."
    "$APKSIGNER" verify --verbose "$SIGNED_APK"
else
    echo "Error: Failed to sign APK"
    exit 1
fi
