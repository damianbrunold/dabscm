namespace scheme;

public class TextOutputStream : TextWriter
{
    private TextWriter writer;
    public bool IsOpen { get; private set; } = true;

    public TextOutputStream(TextWriter writer)
    {
        this.writer = writer;
    }

    public TextWriter Inner => writer;

    public override System.Text.Encoding Encoding => writer.Encoding;

    public override void Write(char value)
    {
        writer.Write(value);
    }

    public override void Write(char[] buffer, int index, int count)
    {
        writer.Write(buffer, index, count);
    }

    public override void Write(string? value)
    {
        writer.Write(value);
    }

    public override void Flush()
    {
        writer.Flush();
    }

    public override void Close()
    {
        IsOpen = false;
        writer.Close();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            IsOpen = false;
            writer.Dispose();
        }
        base.Dispose(disposing);
    }

    public override string ToString()
    {
        return writer.ToString()!;
    }
}
