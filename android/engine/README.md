# Local X5 runtime input

Place the original arm64 TBS 46285 archive at
`android/engine/tbs_core_release.tbs.apk` before building. The APK is ignored by
Git and must not be committed or redistributed without confirming vendor terms.

Required SHA-256:
`a58b1e6d700b01a8341793b4175a41c51b02ecc8e1d6d367f460ea692277d081`

This is the archive tested from https://github.com/HeartHappy/WebX5Core.
The build verifies the input and generates the API-36-only extension patch.
On device, the SDK installs the original archive; the application verifies and
backs up the installed extension before applying the tested patch.

Native libraries are unmodified. This is not an official Android 16-compatible
Tencent build and does not establish support on every API 36 device.
