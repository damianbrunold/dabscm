namespace scheme;

/// <summary>
/// A Record is like a vector but a distinct data type.
/// Records are used by the SRFI-9 define-record-type implementation.
/// The first slot (index 0) holds the record type descriptor (itself a Record).
/// </summary>
public class Record
{
    public readonly object[] Fields;

    public Record(int size)
    {
        Fields = new object[size];
        for (int i = 0; i < size; i++)
            Fields[i] = Value.F;
    }
}
