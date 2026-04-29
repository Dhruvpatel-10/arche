# Development runtimes — languages and toolchains.
# Used by: scripts/08-runtimes.sh
# Note: fnm, bun, rustup are installed via their own install scripts, not pacman.

PACMAN_PKGS=(
    rust                     # Rust via pacman (or use rustup manually)
    go                       # Go toolchain
    cmake
    clang
    gdb

    # Android / React Native — JDK pinned to 17 for current Gradle + Expo
    jdk17-openjdk            # required by Android SDK build-tools and Gradle
    android-udev             # udev rules so non-root users see Android devices for adb
)

AUR_PKGS=(
    # Android SDK split — installs to /opt/android-sdk (group: android-sdk).
    # Required for Expo / React Native `run:android` (gradle wrapper invokes
    # build-tools + platform from $ANDROID_HOME).
    # adb comes from android-sdk-platform-tools — do NOT also install
    # extra/android-tools, it collides on /usr/bin/adb and lacks the rest of the SDK.
    android-sdk
    android-sdk-platform-tools
    android-sdk-build-tools
    android-platform
)
