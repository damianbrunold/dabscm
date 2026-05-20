namespace schemerepl;

public interface ICompletionProvider
{
    IList<string> Completions(string prefix);
    string InfoLine(string name);
}
