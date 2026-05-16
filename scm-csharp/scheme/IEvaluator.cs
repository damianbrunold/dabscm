namespace scheme;

public interface IEvaluator
{
    object Eval(SourcePos? pos, object expr);
    object EvalFile(string file);
    object EvalFile(TextStream reader, string file);
    object Read(TextStream reader);
}
