package scheme;

import java.util.List;

public class Lambda {
    public String name;
    public String doc;
    public Object env;
    public List<Instruction> code;
    // code as an array, for the VM's dispatch loop
    public Instruction[] codeArr;

    public Lambda(Object env, List<Instruction> code) {
        this.env = env;
        setCode(code);
    }

    public void setCode(List<Instruction> code) {
        this.code = code;
        this.codeArr = code instanceof CodeList ? ((CodeList) code).array()
                                                : code.toArray(new Instruction[0]);
    }

    @Override
    public String toString() {
        return "#<" + (name == null ? "lambda" : name ) + ">";
    }
}
