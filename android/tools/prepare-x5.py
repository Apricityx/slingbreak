#!/usr/bin/env python3
"""Prepare pinned offline X5 assets, retaining the original vendor APK."""
import hashlib
import shutil
import sys
import zipfile
from pathlib import Path

CORE_HASH = 'a58b1e6d700b01a8341793b4175a41c51b02ecc8e1d6d367f460ea692277d081'
PATCH_HASH = '448b783e96d74024c19290e0bc7ec7d7a24004ebf337a1aae03c08502c326105'
mode, core, work = sys.argv[1:4]
core, work = Path(core), Path(work)
if not core.is_file():
    raise SystemExit('Missing pinned X5 core: android/engine/tbs_core_release.tbs.apk; see android/README.md')
if hashlib.sha256(core.read_bytes()).hexdigest() != CORE_HASH:
    raise SystemExit('X5 core SHA-256 mismatch; refusing unknown vendor runtime')
work.mkdir(parents=True, exist_ok=True)
if mode == 'extract':
    with zipfile.ZipFile(core) as source:
        (work / 'original.jar').write_bytes(source.read('assets/webkit/tbs_sdk_extension_dex.jar'))
    with zipfile.ZipFile(work / 'original.jar') as source:
        (work / 'original.dex').write_bytes(source.read('classes.dex'))
elif mode == 'patch':
    target = work / 'smali/com/tencent/tbs/sdk/extension/partner/PartnerSDKExtensionServiceImpl.smali'
    text = target.read_text()
    release = '    :cond_6d\n    sget-object p1, Landroid/os/Build$VERSION;->RELEASE:Ljava/lang/String;'
    release_patch = '''    :cond_6d
    sget p1, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v0, 0x24

    if-eq p1, v0, :cond_8d

    sget-object p1, Landroid/os/Build$VERSION;->RELEASE:Ljava/lang/String;'''
    sdk = '''    :try_start_af
    sget p1, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v0, 0xe'''
    sdk_patch = '''    :try_start_af
    sget p1, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v0, 0x24

    if-eq p1, v0, :cond_ba

    const/16 v0, 0xe'''
    for before, after in [(release, release_patch), (sdk, sdk_patch)]:
        if text.count(before) != 1:
            raise SystemExit('X5 patch anchors changed; refusing to patch')
        text = text.replace(before, after)
    target.write_text(text)
elif mode == 'bundle':
    assets = Path(sys.argv[4]) / 'x5'
    assets.mkdir(parents=True, exist_ok=True)
    jar = work / 'api36-extension.jar'
    with zipfile.ZipFile(work / 'original.jar') as source, zipfile.ZipFile(jar, 'w') as out:
        for entry in source.infolist():
            out.writestr(entry, (work / 'api36.dex').read_bytes() if entry.filename == 'classes.dex' else source.read(entry.filename))
    if hashlib.sha256(jar.read_bytes()).hexdigest() != PATCH_HASH:
        raise SystemExit('Generated extension differs from tested deterministic patch')
    shutil.copyfile(jar, assets / 'api36-extension.jar')
    shutil.copyfile(core, assets / 'tbs_core_release.tbs.apk')
    # Ensure PackageManager selects a 64-bit process, even though the rest of
    # the vendor native libraries remain inside the SDK's offline archive.
    jni = Path(sys.argv[4]).parent / 'x5-jni/arm64-v8a'
    jni.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(core) as source:
        (jni / 'liblinuxtoolsfortbssdk_jni.so').write_bytes(source.read('lib/arm64-v8a/liblinuxtoolsfortbssdk_jni.so'))
else:
    raise SystemExit('Unknown mode')
