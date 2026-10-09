package io.github.apricityx.slingbreak.update;

import java.math.BigInteger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Mirrors the reference launcher's dev < RC < stable < hotfix ordering.
 * Unknown tags are NOT considered newer just because their text differs. */
public final class Versions {
    private static final Pattern PATTERN = Pattern.compile(
        "^(\\d+)\\.(\\d+)\\.(\\d+)(?:(?:-dev(\\d+))|(?:-RC(\\d+))|(?:-hotfix(\\d+)))?$",
        Pattern.CASE_INSENSITIVE);
    private Versions() {}

    public static String normalize(String value) {
        String text = value == null ? "" : value.trim();
        return text.startsWith("v") || text.startsWith("V") ? text.substring(1) : text;
    }

    public static Integer compare(String left, String right) {
        BigInteger[] a = parse(left), b = parse(right);
        if (a == null || b == null) return null;
        for (int i = 0; i < a.length; i++) {
            int comparison = a[i].compareTo(b[i]);
            if (comparison != 0) return comparison;
        }
        return 0;
    }

    public static boolean newer(String current, String remote) {
        Integer comparison = compare(current, remote);
        return comparison != null && comparison < 0;
    }

    public static boolean stable(String value) {
        BigInteger[] parsed = parse(value);
        return parsed != null && parsed[3].signum() >= 0;
    }

    private static BigInteger[] parse(String value) {
        Matcher match = PATTERN.matcher(normalize(value));
        if (!match.matches()) return null;
        int stage = match.group(4) != null ? -2 : match.group(5) != null ? -1 : match.group(6) != null ? 1 : 0;
        String number = match.group(4) != null ? match.group(4) : match.group(5) != null ? match.group(5) : match.group(6);
        return new BigInteger[] {new BigInteger(match.group(1)), new BigInteger(match.group(2)),
            new BigInteger(match.group(3)), BigInteger.valueOf(stage), new BigInteger(number == null ? "0" : number)};
    }
}
