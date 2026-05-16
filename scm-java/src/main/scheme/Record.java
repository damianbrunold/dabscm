package scheme;

/**
 * A Record is like a vector but a distinct data type.
 * Records are used by the SRFI-9 define-record-type implementation.
 * The first slot (index 0) holds the record type descriptor (itself a Record).
 */
public class Record {
    public final Object[] fields;

    public Record(int size) {
        fields = new Object[size];
        for (int i = 0; i < size; i++)
            fields[i] = Value.F;
    }
}
