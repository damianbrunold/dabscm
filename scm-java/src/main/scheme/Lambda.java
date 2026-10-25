package scheme;

import java.util.List;

public class Lambda {
    public String name;
    public String doc;
    public Object env;
    public List<Instruction> code;
    // code as a CodeList (code itself, or a copy of another list)
    public CodeList cl;
    // code as an array, for the VM's dispatch loop
    public Instruction[] codeArr;

    public Lambda(Object env, List<Instruction> code) {
        this.env = env;
        setCode(code);
    }

    public void setCode(List<Instruction> code) {
        this.code = code;
        if (code instanceof CodeList) {
            cl = (CodeList) code;
        } else {
            cl = new CodeList();
            cl.addAll(code);
        }
        this.codeArr = cl.array();
    }

    @Override
    public String toString() {
        return "#<" + (name == null ? "lambda" : name ) + ">";
    }
}
