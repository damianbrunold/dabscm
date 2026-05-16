package scheme;

public class SourcePos {
    public String filename;
    public int line;
    public int column;

    public SourcePos(String filename, int line, int column) {
	this.filename = filename;
	this.line = line;
	this.column = column;
    }

    public Object toSexpr() {
	return new Pair(
	    filename.toCharArray(),
	    new Pair(
		(long)line,
		new Pair(
		    (long)column,
		    Value.NIL)));
    }
    
    public String toString() {
	return filename + " " + line + ":" + column;
    }
}
