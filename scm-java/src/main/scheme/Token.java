package scheme;

public class Token {
    public String value;
    public TokenType type;
    public SourcePos pos;

    public Token(String value, TokenType type, SourcePos pos) {
        this.value = value;
        this.type = type;
	this.pos = pos;
    }

    public Object toSexpr() {
	if (pos != null) {
	    return new Pair(
		value.toCharArray(),
		new Pair(
		    type.toString(),
		    new Pair(
			pos.toSexpr(),
			Value.NIL)));
	} else {
	    return new Pair(
		value.toCharArray(),
		new Pair(
		    type.toString(),
		    Value.NIL));
	}
    }

    @Override
    public String toString() {
        return value + " (" + type + ") @" + pos;
    }
}
