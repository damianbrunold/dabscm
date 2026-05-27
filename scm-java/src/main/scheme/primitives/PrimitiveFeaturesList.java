package scheme.primitives;

import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveFeaturesList extends Primitive {
    @Override
    public String name() {
        return "%features-list";
    }

    @Override
    public String info() {
        return "Syntax: (%features-list)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive that returns the list of feature symbols for this implementation (used by (features)). Includes r7rs, scm, platform, and architecture identifiers.\n" +
               "Example:\n" +
               "  (%features-list) => (r7rs scm exact-closed ieee-float gnu-linux x86-64 little-endian)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);

        List<String> features = new ArrayList<>();
        features.add("r7rs");
        features.add("scm");
        features.add("exact-closed");
        features.add("ieee-float");

        // Supported SRFIs
        for (String srfi : new String[] {
            "srfi-1", "srfi-2", "srfi-8", "srfi-9", "srfi-13", "srfi-14",
            "srfi-18", "srfi-19", "srfi-26", "srfi-28", "srfi-39", "srfi-64",
            "srfi-69", "srfi-95", "srfi-98", "srfi-111", "srfi-125", "srfi-128",
            "srfi-132", "srfi-133", "srfi-151", "srfi-158" })
            features.add(srfi);

        // OS platform
        String osName = System.getProperty("os.name", "").toLowerCase();
        if (osName.contains("linux")) {
            features.add("gnu-linux");
            features.add("unix");
        } else if (osName.contains("mac") || osName.contains("darwin")) {
            features.add("darwin");
            features.add("unix");
        } else if (osName.contains("windows")) {
            features.add("windows");
        }

        // Architecture
        String osArch = System.getProperty("os.arch", "").toLowerCase();
        if (osArch.equals("amd64") || osArch.equals("x86_64")) {
            features.add("x86-64");
        } else if (osArch.equals("x86") || osArch.equals("i386") || osArch.equals("i686")) {
            features.add("i386");
        } else if (osArch.equals("aarch64")) {
            features.add("arm64");
        } else if (osArch.startsWith("arm")) {
            features.add("arm");
        }

        // Endianness
        features.add(ByteOrder.nativeOrder() == ByteOrder.LITTLE_ENDIAN ? "little-endian" : "big-endian");

        Object result = Value.NIL;
        for (int i = features.size() - 1; i >= 0; i--)
            result = new Pair(Value.intern(features.get(i)), result);
        return result;
    }
}
