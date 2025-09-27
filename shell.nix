{ pkgs ? import <nixpkgs> {} }:

let
  # Android SDK components
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    buildToolsVersions = [ "35.0.0" ];
    platformVersions = [ "34" ];
    abiVersions = [ "x86_64" "arm64-v8a" ];
    includeEmulator = false;
    includeSystemImages = false;
    includeNDK = false;
    includeExtras = [
      "extras;google;m2repository"
      "extras;android;m2repository"
    ];
  };

  androidSdk = androidComposition.androidsdk;

  # Custom Gradle 6.9.4 (last version before 7.0)
  gradle_6_9 = pkgs.stdenv.mkDerivation rec {
    pname = "gradle";
    version = "6.9.4";
    
    src = pkgs.fetchurl {
      url = "https://services.gradle.org/distributions/gradle-${version}-bin.zip";
      sha256 = "sha256-PiQCKFON6fGHcqV06ZoLqVnoPW7zUQFDgazZYxeBOJo=";
    };
    
    nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];
    
    installPhase = ''
      mkdir -p $out/gradle
      cp -r * $out/gradle
      
      mkdir -p $out/bin
      makeWrapper $out/gradle/bin/gradle $out/bin/gradle \
        --prefix PATH : ${pkgs.jdk11}/bin \
        --set JAVA_HOME ${pkgs.jdk11}
    '';
  };

in
pkgs.mkShell {
  name = "bitcoin-wallet-android-dev";

  buildInputs = with pkgs; [
    # Java Development Kit
    jdk11

    # Android SDK
    androidSdk

    # Custom Gradle 6.9.4
    gradle_6_9

    # Build tools
    git
    which
    unzip
    file

    # Optional: for reproducible builds
    buildah
    podman

    # Optional: for debugging
    android-tools  # provides adb
  ];

  shellHook = ''
    export ANDROID_HOME="${androidSdk}/libexec/android-sdk"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export PATH="${gradle_6_9}/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH"

    # Gradle configuration
    export GRADLE_OPTS="-Xmx2048M -Dfile.encoding=UTF-8"
    export GRADLE_USER_HOME="$HOME/.gradle"

    # Java configuration
    export JAVA_HOME="${pkgs.jdk11}"

    # Create a local gradle.properties if it doesn't exist
    if [ ! -f "$HOME/.gradle/gradle.properties" ]; then
      mkdir -p "$HOME/.gradle"
      cat > "$HOME/.gradle/gradle.properties" <<EOF
# Gradle performance improvements
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.configureondemand=false
org.gradle.caching=true

# Android build improvements
android.useAndroidX=true
android.enableJetifier=true
EOF
    fi

    echo "Bitcoin Wallet Android Development Environment"
    echo "============================================="
    echo "Android SDK: $ANDROID_HOME"
    echo "Java: $(java -version 2>&1 | head -n 1)"
    echo ""
    echo "Build commands:"
    echo "  Development build: gradle clean test :wallet:assembleDevDebug"
    echo "  Production build:  gradle clean test :wallet:assembleProdRelease"
    echo "  Install to device: gradle :wallet:installDevDebug"
    echo "  Run all tests:     gradle test"
    echo ""
    echo "Debugging Gradle issues:"
    echo "  gradle --version --no-daemon    # Check version without daemon"
    echo "  gradle --stop                   # Stop any running daemons"
    echo "  gradle --status                 # Check daemon status"
    echo ""
    echo "Make sure to accept Android SDK licenses if this is your first time:"
    echo "  yes | sdkmanager --licenses"
  '';

  # Set up environment variables
  ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
  JAVA_HOME = "${pkgs.jdk11}";
}
