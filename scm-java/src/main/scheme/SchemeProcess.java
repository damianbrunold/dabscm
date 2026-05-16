package scheme;

public class SchemeProcess {
    public Process process;

    public SchemeProcess(Process process) { this.process = process; }

    @Override
    public String toString() { return "#<process " + process.pid() + ">"; }
}
