namespace scheme;

public class ReadErrorObject : ErrorObject
{
    public ReadErrorObject(string message, object[] irritants)
        : base(message, irritants) { }
}
