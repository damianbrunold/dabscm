package scheme;

public interface IEvaluator {
    Object eval(SourcePos pos, Object expr);
    Object evalFile(java.io.File file);
    Object evalFile(TextStream reader, String file);
    Object read(TextStream reader);
}
