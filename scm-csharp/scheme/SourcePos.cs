namespace scheme;

public class SourcePos
{
    public string filename;
    public int line;
    public int column;

    public SourcePos(string filename, int line, int column)
    {
	this.filename = filename;
	this.line = line;
	this.column = column;
    }

    public object ToSexpr()
    {
	return new Pair(
	    filename.ToCharArray(),
	    new Pair(
		(long)line,
		new Pair(
		    (long)column,
		    Value.NIL)));
    }
    
    public override string ToString()
    {
	return filename + " " + line + ":" + column;
    }
}
