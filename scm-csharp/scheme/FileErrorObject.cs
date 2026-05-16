namespace scheme;

public class FileErrorObject : ErrorObject
{
    public FileErrorObject(string message, object[] irritants)
        : base(message, irritants) { }
}
