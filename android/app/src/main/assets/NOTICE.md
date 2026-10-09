# Slingbreak Android third-party notices

Game resources are bundled verbatim from https://github.com/Apricityx/slingbreak.
See that repository and vendor source headers for the applicable terms.

## Tencent X5 / TBS

- SDK: com.tencent.tbs:tbssdk:44286 (4.3.0.386)
- Bundled arm64 core: 46285, Chromium 89.0.4389.72
- Vendor: https://x5.tencent.com/
- Archive reference: https://github.com/HeartHappy/WebX5Core

The extension DEX is modified with API-36-only exceptions to its RELEASE and
SDK range checks. Native libraries remain unmodified. This is not an official
Tencent Android 16-compatible runtime. The original archive and tested patch
are SHA-256 pinned; the original extension is retained on device.

Tencent SDK/core and bundled third-party components retain their own terms.
The reference project's availability does not grant redistribution rights to
the vendor core. Permission for release redistribution/modification has not been
confirmed: do not publish this APK until those terms have been verified. No
GeckoView/Gecko runtime is bundled in this version.

The host disables SDK download/query/reporting switches and rejects external
page/subresource loads. These settings are not a network audit of vendor code;
native vendor components may have additional network behavior.

## AndroidX and Android APK signature verifier

Apache License 2.0: https://www.apache.org/licenses/LICENSE-2.0

- AndroidX: https://android.googlesource.com/platform/frameworks/support/
- apksig: https://android.googlesource.com/platform/tools/apksig/

## Game vendors

- Matter.js: MIT, https://github.com/liabru/matter-js
- Lucide: ISC, https://github.com/lucide-icons/lucide

Release checks use GitHub's public API. Optional third-party download mirrors
are disabled by default. No account, token or arbitrary JS bridge is required
for gameplay. Vendor SDK behavior is governed separately by its own terms.
