package io.github.apricityx.slingbreak.update;

import org.junit.Test;
import static org.junit.Assert.*;
import java.io.IOException;

public class GithubHttpTest {
    @Test public void unsafeTransportRejectedBeforeAnyConnection() {
        for (String url : new String[] {"http://github.com/file.apk", "file:///etc/passwd", "https://localhost/",
            "https://evil.test/", "https://github.com:444/", "https://user:secret@github.com/", "https://ghproxy.vip/https://evil.test/"}) {
            try { new GithubHttp().open(url, "GET", false); fail(url); }
            catch (IOException expected) { assertTrue(expected.getMessage().contains("白名单")); }
        }
    }
}
