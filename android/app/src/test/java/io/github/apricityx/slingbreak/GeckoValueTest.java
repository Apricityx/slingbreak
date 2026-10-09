package io.github.apricityx.slingbreak;

import org.junit.Test;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import static org.junit.Assert.*;

public class GeckoValueTest {
    @Test public void utf8AndUtf16() throws Exception {
        String text = "save-\u4e2d\ud83d\ude00";
        assertEquals(text, GeckoValue.decode(text.getBytes(StandardCharsets.UTF_8), text.length(), 1, 0));
        assertEquals(text, GeckoValue.decode(text.getBytes(StandardCharsets.UTF_16LE), text.length(), 0, 0));
    }
    @Test public void snappyLiteralsAndOverlappingCopies() throws Exception {
        assertEquals("abcabcabc", GeckoValue.decode(new byte[] {9, 8, 'a', 'b', 'c', 22, 3, 0}, 9, 1, 1));
        assertEquals("aaaaaaaaa", GeckoValue.decode(new byte[] {9, 0, 'a', 17, 1}, 9, 1, 1));
        assertEquals("abcabc", GeckoValue.decode(new byte[] {6, 8, 'a', 'b', 'c', 11, 3, 0, 0, 0}, 6, 1, 1));
    }
    @Test public void malformedAndUnknownDataRejected() throws Exception {
        for (byte[] input : new byte[][] {new byte[] {}, {9, 17, 1}, {1, 0}, {0, 0, 1}, {(byte) 255,(byte) 255,(byte) 255,(byte) 255,127}}) {
            try { GeckoValue.decode(input, 1, 1, 1); fail("accepted invalid data"); } catch (IOException expected) {}
        }
        try { GeckoValue.decode(new byte[] {(byte) 255}, 1, 1, 0); fail(); } catch (IOException expected) {}
        try { GeckoValue.decode(new byte[] {1}, 1, 0, 0); fail(); } catch (IOException expected) {}
        try { GeckoValue.decode(new byte[] {1}, 1, 2, 0); fail(); } catch (IOException expected) {}
    }
}
