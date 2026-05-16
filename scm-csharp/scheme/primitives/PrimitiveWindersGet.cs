namespace scheme;

class PrimitiveWindersGet : Primitive {
    public override string Name() => "%winders-get";
    public override string Info()
    {
        return
            "Syntax: (%winders-get)\n" +
            "Library: (scm core)\n" +
            "Description: Returns the current winder chain list used by dynamic-wind to track before/after thunks.\n" +
            "Example:\n" +
            "  (%winders-get) => ()";
    }
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 0, 0);
        return VM.Current?.winders ?? Value.NIL;
    }
}
