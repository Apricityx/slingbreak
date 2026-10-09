package io.github.apricityx.slingbreak.update;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import static org.junit.Assert.*;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.concurrent.atomic.AtomicInteger;

public class ApkDownloadTest {
    @Rule public TemporaryFolder temp = new TemporaryFolder();
    private final byte[] payload = {1, 2, 3, 4};
    private UpdateService.Result result(String digest) {
        Release release = new Release("v2.0.0", "notes", "slingbreak-2.0.0-arm64-v8a.apk",
            "https://github.com/Apricityx/slingbreak/releases/download/v2.0.0/slingbreak-2.0.0-arm64-v8a.apk", digest, payload.length);
        return new UpdateService.Result(release, true, UpdateSource.GITHUB, UpdateSource.GITHUB);
    }
    private HttpURLConnection response(byte[] body, long length) throws Exception {
        return new HttpURLConnection(new URL("https://github.com")) {
            public void disconnect() {}
            public boolean usingProxy() { return false; }
            public void connect() {}
            public InputStream getInputStream() { return new ByteArrayInputStream(body); }
            public long getContentLengthLong() { return length; }
        };
    }
    private ApkDownload download(byte[] body, long length) throws Exception {
        HttpURLConnection response = response(body, length);
        return new ApkDownload(url -> response);
    }
    private void fails(ApkDownload task, UpdateService.Result result, ApkDownload.Validator validator) throws Exception {
        File folder = temp.newFolder();
        try {
            task.download(folder, result, false, (bytes, total) -> {}, validator);
            fail("Must reject this download");
        } catch (IOException expected) {
            assertFalse(new File(folder, "update.part").exists());
            assertFalse(new File(folder, "update.apk").exists());
        }
    }
    @Test public void verifiedFileIsPromotedOnlyAfterValidation() throws Exception {
        File folder = temp.newFolder();
        String digest = ApkVerifier.hex(MessageDigest.getInstance("SHA-256").digest(payload));
        AtomicInteger validation = new AtomicInteger(), last = new AtomicInteger();
        File apk = download(payload, payload.length).download(folder, result(digest), false,
            (bytes, total) -> last.set((int) bytes), (file, release) -> {
                assertEquals("update.part", file.getName());
                assertFalse(new File(folder, "update.apk").exists());
                validation.incrementAndGet();
            });
        assertArrayEquals(payload, Files.readAllBytes(apk.toPath()));
        assertEquals(1, validation.get());
        assertEquals(payload.length, last.get());
        assertFalse(new File(folder, "update.part").exists());
    }
    @Test public void missingDigestStillRequiresSignatureValidator() throws Exception {
        fails(download(payload, payload.length), result(""), (file, release) -> { throw new IOException("wrong signer"); });
    }
    @Test public void incorrectDigestRejectedBeforeValidator() throws Exception {
        fails(download(payload, payload.length), result("0".repeat(64)), (file, release) -> fail("Must not verify incorrect checksum"));
    }
    @Test public void truncatedBodyRejected() throws Exception {
        fails(download(new byte[] {1}, -1), result(""), (file, release) -> fail("Must not verify truncated APK"));
    }
    @Test public void oversizedBodyRejected() throws Exception {
        fails(download(new byte[5], -1), result(""), (file, release) -> fail("Must not verify oversized APK"));
    }
    @Test public void incorrectContentLengthRejected() throws Exception {
        fails(download(payload, 5), result(""), (file, release) -> fail("Must not verify incorrect length"));
    }
    @Test public void cancellationCleansPartialDownload() throws Exception {
        ApkDownload task = download(payload, payload.length);
        File folder = temp.newFolder();
        try {
            task.download(folder, result(""), false, (bytes, total) -> task.cancel(), (file, release) -> fail("Cancelled download"));
            fail("Expected cancellation");
        } catch (IOException expected) {
            assertEquals("已取消下载", expected.getMessage());
            assertFalse(new File(folder, "update.part").exists());
            assertFalse(new File(folder, "update.apk").exists());
        }
    }
    @Test public void optInFallbackRetriesWholeFileNotAppending() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        HttpURLConnection broken = response(new byte[] {1}, -1), valid = response(payload, payload.length);
        ApkDownload task = new ApkDownload(url -> calls.incrementAndGet() == 1 ? broken : valid);
        File folder = temp.newFolder();
        File apk = task.download(folder, result(""), true, (bytes, total) -> {}, (file, release) -> {});
        assertArrayEquals(payload, Files.readAllBytes(apk.toPath()));
        assertEquals(2, calls.get());
    }
}
