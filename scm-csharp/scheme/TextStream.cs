namespace scheme;

public class TextStream : IDisposable
{
    private TextReader reader;
    private string filename;
    private int line = 1;
    private int column = 0;

    public bool FoldCase { get; set; } = false;
    public bool IsOpen { get; private set; } = true;

    public TextStream(TextReader reader, string filename)
    {
	this.reader = reader;
	this.filename = filename;
    }

    public void Dispose()
    {
	this.reader.Dispose();
    }

    public void SetPosition(int line, int column)
    {
	this.line = line;
	this.column = column;
    }

    public string? ReadToEnd()
    {
	// TODO do we need to track the position here? probably not...
	return this.reader.ReadToEnd();
    }

    public string? ReadLine()
    {
        var result = this.reader.ReadLine();
        this.line++;
        this.column = 0;
        return result;
    }
    
    public int Read()
    {
	int c = this.reader.Read();
	if (c == '\n')
	{
	    this.line++;
	    this.column = 0;
	}
	else
	{
	    this.column++;
	}
	return c;
    }

    public int Peek()
    {
	return this.reader.Peek();
    }

    public void Close()
    {
        IsOpen = false;
	this.reader.Close();
    }

    public string Filename()
    {
	return filename;
    }
    
    public int Line()
    {
	return line;
    }

    public int Column()
    {
	return column;
    }

    public SourcePos Pos()
    {
	return new SourcePos(filename, line, column);
    }
}
