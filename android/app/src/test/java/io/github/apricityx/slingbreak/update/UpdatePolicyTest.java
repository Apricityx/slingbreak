package io.github.apricityx.slingbreak.update;

import org.junit.Test;
import static org.junit.Assert.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class UpdatePolicyTest {
    private static final String[] ARM = {"arm64-v8a", "armeabi-v7a"};
    private JSONObject asset(String name) {
        try {
            return new JSONObject().put("name", name).put("size", 100).put("state", "uploaded")
                .put("browser_download_url", "https://github.com/Apricityx/slingbreak/releases/download/v1.2.0/" + name);
        } catch (Exception error) { throw new IllegalStateException(error); }
    }
    private JSONObject release() {
        try {
            return new JSONObject().put("tag_name", "v1.2.0").put("body", "notes\r\nnext")
                .put("assets", new JSONArray().put(asset("slingbreak-1.2.0-arm64-v8a.apk")));
        } catch (Exception error) { throw new IllegalStateException(error); }
    }

    @Test public void prefixAndNumericalOrdering() {
        assertEquals(0, Versions.compare(" V1.0.0 ", "1.0.0").intValue());
        assertTrue(Versions.newer("1.9.0", "v1.10.0"));
        assertFalse(Versions.newer("2.0.0", "1.99.0"));
        assertFalse(Versions.newer("1.0.0", "v1.0.0"));
    }
    @Test public void stagesMatchReference() {
        String[] versions = {"1.0.0-dev1", "1.0.0-dev2", "1.0.0-RC1", "1.0.0-RC10", "1.0.0", "1.0.0-hotfix1", "1.0.0-hotfix2", "1.0.1-dev1"};
        for (int i = 1; i < versions.length; i++) assertTrue(versions[i], Versions.newer(versions[i - 1], versions[i]));
        assertFalse(Versions.stable("1.0.0-RC1"));
        assertTrue(Versions.stable("1.0.0-hotfix1"));
    }
    @Test public void unknownTagsCannotTriggerDowngrade() {
        assertNull(Versions.compare("1.0.0", "banana"));
        for (String tag : new String[] {"", "latest", "1.0", "1.0.0+build", "1.0.0-rc", "-1.0.0", "1.0.0-dev-1"}) {
            assertFalse(tag, Versions.newer("1.0.0", tag));
        }
        assertTrue(Versions.newer("1.0.0", "99999999999999999999999999.0.0"));
    }
    @Test public void assetMatchesDeviceAbiNotFirstApk() throws Exception {
        JSONObject json = release().put("assets", new JSONArray()
            .put(asset("slingbreak-1.2.0-x86_64.apk"))
            .put(asset("slingbreak-1.2.0-universal.apk"))
            .put(asset("slingbreak-1.2.0-armeabi-v7a.apk"))
            .put(asset("slingbreak-1.2.0-arm64-v8a.apk")));
        assertTrue(Release.parse(json, ARM).name.endsWith("-arm64-v8a.apk"));
        assertTrue(Release.parse(json, new String[] {"x86_64"}).name.endsWith("-x86_64.apk"));
        assertTrue(Release.parse(json, new String[] {"unknown"}).name.endsWith("-universal.apk"));
    }
    @Test public void wrongArchitectureAndTestBuildsRejected() throws Exception {
        for (String name : new String[] {"another-arm64-v8a.apk", "slingbreak-debug-arm64-v8a.apk",
            "slingbreak-unsigned-arm64-v8a.apk", "slingbreak-1.2.0-x86_64.apk", "slingbreak-1.2.0-arm64-v8a.apk.exe"}) {
            assertNull(name, Release.parse(release().put("assets", new JSONArray().put(asset(name))), ARM));
        }
    }
    @Test public void draftsPrereleasesAndInvalidTagsRejected() throws Exception {
        assertNull(Release.parse(release().put("draft", true), ARM));
        assertNull(Release.parse(release().put("prerelease", true), ARM));
        assertNull(Release.parse(release().put("tag_name", "nightly"), ARM));
        assertNull(Release.parse(release().put("tag_name", "v1.2.0-RC1"), ARM));
    }
    @Test public void sizeAndStateValidated() throws Exception {
        for (long size : new long[] {0, -1, Release.MAX_APK_BYTES + 1}) {
            assertNull(Release.parse(release().put("assets", new JSONArray().put(asset("slingbreak-1.2.0-arm64-v8a.apk").put("size", size))), ARM));
        }
        assertNull(Release.parse(release().put("assets", new JSONArray().put(asset("slingbreak-1.2.0-arm64-v8a.apk").put("state", "new"))), ARM));
    }
    @Test public void notesAndDigestNormalized() throws Exception {
        JSONObject json = release();
        json.getJSONArray("assets").getJSONObject(0).put("digest", "sha256:" + "A".repeat(64));
        Release parsed = Release.parse(json, ARM);
        assertEquals("notes\nnext", parsed.notes);
        assertEquals("a".repeat(64), parsed.sha256);
        json.getJSONArray("assets").getJSONObject(0).put("digest", JSONObject.NULL);
        assertEquals("", Release.parse(json, ARM).sha256);
    }
    @Test(expected = IllegalArgumentException.class) public void malformedChecksumRejected() throws Exception {
        JSONObject json = release();
        json.getJSONArray("assets").getJSONObject(0).put("digest", "sha256:not-a-checksum");
        Release.parse(json, ARM);
    }
    @Test public void sourcePolicyIsOfficialFirstAndOptIn() {
        assertEquals(List.of(UpdateSource.GITHUB), UpdateSource.candidates(false, false));
        assertEquals(List.of(UpdateSource.GITHUB, UpdateSource.VIP, UpdateSource.LLKK), UpdateSource.candidates(true, true));
        assertEquals(List.of(UpdateSource.GITHUB, UpdateSource.VIP, UpdateSource.LLKK, UpdateSource.PROXY), UpdateSource.candidates(true, false));
        assertEquals("https://ghproxy.vip/" + UpdateService.API, UpdateSource.VIP.url(UpdateService.API));
    }
    @Test public void urlsCannotEscapeRepositoryOrHttps() {
        String good = "https://github.com/Apricityx/slingbreak/releases/download/v1.2.0/slingbreak-1.2.0-arm64-v8a.apk";
        assertTrue(Release.validAssetUrl(good, "v1.2.0"));
        for (String bad : new String[] {good.replace("https:", "http:"), good.replace("github.com", "evil.test"),
            good.replace("github.com", "github.com.evil.test"), good.replace("github.com", "user@github.com"),
            good.replace("github.com", "github.com:443"), good.replace("Apricityx", "Someone"),
            good.replace("v1.2.0/", "v0.1.0/"), good + "?redirect=evil", good.replace("/slingbreak-", "/../slingbreak-"),
            good.replace("github.com", "release-assets.githubusercontent.com")}) {
            assertFalse(bad, Release.validAssetUrl(bad, "v1.2.0"));
        }
        assertTrue(UpdateSource.allowedTransportUrl("https://release-assets.githubusercontent.com/asset"));
        assertFalse(UpdateSource.allowedTransportUrl("https://evilgithubusercontent.com/asset"));
        assertFalse(UpdateSource.allowedTransportUrl("https://ghproxy.vip/https://evil.test/asset"));
    }
    @Test public void noReleaseIsDistinctFromNetworkFailure() throws Exception {
        UpdateService service = new UpdateService(new UpdateService.Transport() {
            public String text(String url) throws IOException { throw new GithubHttp.HttpError(404, "not found"); }
            public boolean reachable(String url) { fail("404 must not probe APKs"); return false; }
        });
        assertNull(service.check("1.0.0", ARM, true).release);
    }
    @Test public void updateAndNoUpdatePaths() throws Exception {
        List<String> probes = new ArrayList<>();
        UpdateService service = new UpdateService(new UpdateService.Transport() {
            public String text(String url) { return release().toString(); }
            public boolean reachable(String url) { probes.add(url); return true; }
        });
        assertFalse(service.check("1.2.0", ARM, false).newer);
        assertFalse(service.check("2.0.0", ARM, false).newer);
        assertTrue(probes.isEmpty());
        UpdateService.Result result = service.check("1.0.0", ARM, false);
        assertTrue(result.newer);
        assertEquals(UpdateSource.GITHUB, result.downloadSource);
        assertEquals(1, probes.size());
    }
    @Test public void metadataAndDownloadFallbacksAreSeparate() throws Exception {
        UpdateService service = new UpdateService(new UpdateService.Transport() {
            public String text(String url) throws IOException {
                if (url.equals(UpdateService.API)) throw new IOException("network unavailable");
                return release().toString();
            }
            public boolean reachable(String url) { return url.startsWith("https://gh.llkk.cc/"); }
        });
        UpdateService.Result result = service.check("1.0.0", ARM, true);
        assertEquals(UpdateSource.VIP, result.metadataSource);
        assertEquals(UpdateSource.LLKK, result.downloadSource);
    }
    @Test(expected = IOException.class) public void unreachableDownloadFailsVisibly() throws Exception {
        new UpdateService(new UpdateService.Transport() {
            public String text(String url) { return release().toString(); }
            public boolean reachable(String url) { return false; }
        }).check("1.0.0", ARM, false);
    }
    @Test(expected = IOException.class) public void invalidJsonFailsVisibly() throws Exception {
        new UpdateService(new UpdateService.Transport() {
            public String text(String url) { return "<html>bad gateway</html>"; }
            public boolean reachable(String url) { return false; }
        }).check("1.0.0", ARM, false);
    }
    @Test(expected = IOException.class) public void noCompatibleApkFailsVisibly() throws Exception {
        new UpdateService(new UpdateService.Transport() {
            public String text(String url) throws IOException {
                try { return release().put("assets", new JSONArray()).toString(); }
                catch (Exception error) { throw new IOException(error); }
            }
            public boolean reachable(String url) { return false; }
        }).check("1.0.0", ARM, false);
    }
}
