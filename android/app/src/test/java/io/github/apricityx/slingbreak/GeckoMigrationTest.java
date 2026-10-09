package io.github.apricityx.slingbreak;

import org.junit.Test;
import org.json.JSONObject;
import static org.junit.Assert.*;

public class GeckoMigrationTest {
    @Test public void migrationInsertsMissingValuesPreservesExistingAndRetriesWriteFailure() throws Exception {
        String script = GeckoMigration.script(new JSONObject().put(GeckoMigration.SAVE, "legacy").put(GeckoMigration.THEME, "dark"));
        String program = "const vm=require('node:vm'),assert=require('node:assert/strict');const source=" + JSONObject.quote(script) + ";"
            + "function run(existing,fail){const values=new Map(Object.entries(existing));const storage={getItem:k=>values.has(k)?values.get(k):null,"
            + "setItem(k,v){if(fail&&k==='slingbreak-theme')throw Error('quota');values.set(k,v);},removeItem:k=>values.delete(k)};"
            + "vm.runInNewContext(source,{localStorage:storage,console:{info(){},warn(){}}});return values;}"
            + "let values=run({},false);assert.equal(values.get('slingbreak-save-v1'),'legacy');assert.equal(values.get('slingbreak-theme'),'dark');"
            + "values=run({'slingbreak-save-v1':'existing'},false);assert.equal(values.get('slingbreak-save-v1'),'existing');"
            + "values=run({},true);assert.equal(values.size,0);"
            + "values=run({'slingbreak-save-v1':'existing'},true);assert.equal(values.get('slingbreak-save-v1'),'existing');assert.equal(values.size,1);";
        Process process = new ProcessBuilder("node", "-e", program).redirectErrorStream(true).start();
        String output = new String(process.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        assertEquals(output, 0, process.waitFor());
    }
    @Test public void validatesLegacySaveAndEscapesInlineScript() throws Exception {
        assertTrue(GeckoMigration.validSave("{\"level\":4,\"coins\":100,\"total\":20,\"best\":8,\"up\":{\"power\":1,\"arrow\":0,\"brick\":2}}"));
        assertFalse(GeckoMigration.validSave("{\"level\":0}"));
        String script = GeckoMigration.script(new JSONObject().put(GeckoMigration.THEME, "</script>&\u2028"));
        assertFalse(script.contains("</script>")); assertFalse(script.contains("\u2028"));
        assertTrue(script.contains("localStorage.getItem(k)===null"));
        assertTrue(script.contains("localStorage.removeItem(k)"));
    }
}
