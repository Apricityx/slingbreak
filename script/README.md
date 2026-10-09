# Android scripts

These entrypoints are the Slingbreak equivalents of the build/install helpers
from `SlayTheAmethystModded`. They target this repository's `android/` Gradle
project and package `io.github.apricityx.slingbreak`.

## Build

```sh
./script/build.sh debug
./script/build.sh release
./script/build.sh test
./script/build.sh lint
./script/build.sh check
```

`release` creates the signed, ABI-specific artifacts under
`android/app/build/outputs/distribution/`. Release signing must already be
configured in `android/signing.properties` or through the documented
`SLINGBREAK_*` environment variables.

## Build and install debug

```sh
./script/build-debug-install.sh
./script/build-debug-install.sh 10.126.126.1:5555
./script/build-debug-install.sh --device 10.126.126.1:5555
./script/build-debug-install.sh --help
```

The default device is `10.126.126.1:5555`, matching the configured acceptance
device. Set `SLINGBREAK_DEVICE` to change the default, or pass a serial as the
first argument. `ADB_BIN` and `GRADLE_BIN` can override tool paths.
Set `SLINGBREAK_DEVICE=''` to automatically select the only authorized device.
The device must already be connected; for wireless ADB, run `adb connect`
before invoking the installer.

Debug uses the independent package `io.github.apricityx.slingbreak.debug` and
does not overwrite the release app or share its saves. Extra arguments to
`build.sh` are passed through to Gradle, for example:

```sh
./script/build.sh release -PappVersionName=1.1.0 -PappVersionCode=2
```

The installer builds `:app:assembleDebug`, reads the device ABI list, selects
the matching split APK, and installs it with `adb install -r`. It refuses a
missing, unauthorized, offline, or ambiguous device before building or
installing.
