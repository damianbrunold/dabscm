namespace scheme;

class PrimitiveWindersSet : Primitive {
    public override string Name() => "%winders-set!";
    public override string Info()
    {
        return
            "Syntax: (%winders-set! winders)\n" +
            "Library: (scm core)\n" +
            "Description: Sets the current VM's winder chain to the given list. Used internally by dynamic-wind to save and restore the winder state.\n" +
            "Example:\n" +
            "  (%winders-set! '())";
    }
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 1, 1);
        if (VM.Current != null) VM.Current.winders = args[0];
        return Value.NIL;
    }
}
