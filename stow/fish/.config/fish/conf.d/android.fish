# Android SDK (AUR android-sdk family installs to /opt/android-sdk).
# fish_add_path is idempotent and silently no-ops if the dir is missing,
# so this stays harmless on hosts without the SDK installed.

if test -d /opt/android-sdk
    set -gx ANDROID_HOME /opt/android-sdk
    set -gx ANDROID_SDK_ROOT $ANDROID_HOME
    fish_add_path $ANDROID_HOME/platform-tools
    fish_add_path $ANDROID_HOME/emulator
    fish_add_path $ANDROID_HOME/cmdline-tools/latest/bin
    fish_add_path $ANDROID_HOME/tools/bin
end
