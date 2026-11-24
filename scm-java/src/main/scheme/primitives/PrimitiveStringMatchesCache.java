package scheme.primitives;

import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

/** Compiled-pattern cache for regex-search. */
final class PrimitiveStringMatchesCache {
    private PrimitiveStringMatchesCache() {}

    private static final ConcurrentHashMap<String, Pattern> cache = new ConcurrentHashMap<>();

    static Pattern get(String pattern) {
        Pattern p = cache.get(pattern);
        if (p != null) return p;
        p = RegexPatterns.compile("regex-search", pattern);
        if (cache.size() > 256) cache.clear();
        cache.putIfAbsent(pattern, p);
        return p;
    }
}
