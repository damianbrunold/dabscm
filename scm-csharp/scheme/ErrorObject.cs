using System.Linq;

namespace scheme;

public class ErrorObject {
    public string Message { get; }
    public object[] Irritants { get; }

    public ErrorObject(string message, object[] irritants) {
        Message = message;
        Irritants = irritants;
    }

    public override string ToString() {
        if (Irritants.Length == 0) return Message;
        return Message + ": " + string.Join(", ", Irritants.Select(Value.PrintRep));
    }
}
