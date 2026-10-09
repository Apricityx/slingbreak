package io.github.apricityx.slingbreak;

import org.junit.Test;
import static org.junit.Assert.*;

public class LocalGameTest {
    @Test public void stableBundledOriginOnly() {
        assertTrue(LocalGame.document(LocalGame.GAME + "?client=1#game"));
        assertEquals("game/src/core/game.js", LocalGame.asset(LocalGame.ORIGIN + "/assets/game/src/core/game.js"));
        for (String url : new String[] {"https://evil.test/assets/game/index.html", "http://appassets.androidplatform.net/assets/game/index.html",
                LocalGame.ORIGIN + ":443/assets/game/index.html", "https://user@appassets.androidplatform.net/assets/game/index.html",
                LocalGame.ORIGIN + "/assets/game/../NOTICE.md", LocalGame.ORIGIN + "/assets/game/%2e%2e/NOTICE.md",
                "file:///android_asset/game/index.html", "resource://android/assets/game/index.html"})
            assertNull(url, LocalGame.asset(url));
        assertFalse(LocalGame.document(LocalGame.ORIGIN + "/assets/game/other.html"));
    }
    @Test public void commandsNeedGestureFrameAndSource() {
        String target = "slingbreak://check-update";
        assertTrue(LocalGame.commandAllowed(target, LocalGame.GAME, true, true, false));
        assertTrue(LocalGame.commandAllowed("slingbreak://export-progress", LocalGame.GAME, true, true, false));
        assertFalse(LocalGame.commandAllowed(target, LocalGame.GAME, false, true, false));
        assertFalse(LocalGame.commandAllowed(target, LocalGame.GAME, true, false, false));
        assertFalse(LocalGame.commandAllowed(target, LocalGame.GAME, true, true, true));
        assertFalse(LocalGame.commandAllowed(target, "https://evil.test", true, true, false));
        assertFalse(LocalGame.commandAllowed(target + "?download=evil", LocalGame.GAME, true, true, false));
    }
}
