# Reading the makefile

When started, tclmake by default looks for a "tclmakefile" named 
**makefile.tmk** or **Makefile.tmk**. The tclmakefile can be specified on the 
command line by the "-f" or "--file" option.

If there is no such file, tclmake attempts several things. First, it looks for 
a file named **makefile** or **Makefile**. If it finds one, then it reads it 
(and any files it includes), looking for a variable named **TCLMAKEFILE**. If 
it finds one, it uses its value as the name of the tclmakefile, and gives that 
file an implicit use of the makefile in the current directory (see below).

If neither of the above finds a file, tclmake looks for the environment 
variable **MAKELIB**. If it exists, then it looks for the file default.tmk in 
the directory given by that variable; otherwise, it looks for the file 
**$(TCLMAKE_LIBRARY)/mk/default.tmk** (which must exist). This last file 
contains a number of useful rules for processing directories containing Tcl 
files, and enables operations like cleaning directories and generating tclIndex 
files without needing to bother with writing a makefile or tclmakefile.

Once tclmake has a file, it reads it, looking for [variable 
definitions](./variables.md) and [rules](./rules.md).

It also recognizes the following special directives, if they are the first word 
on a line (that is not part of a command):

`include <filename>`
- Substitute the named file into the input stream.  tclmake treats the named 
file as if its contents had been part of the tclmakefile, inserted at the point 
of the directive.

`use <filename>`
- This is like `include`, except that only variable definitions are extracted 
from the file. This is useful for having tclmake use information such as the 
list of files in the directory from a regular makefile, and saves having to 
maintain two copies. 

`source <filename>`
- Source the named file ino the Tcl interpreter. The file must contain a valid 
Tcl script. This allows arbitrarily complex commands to be executed. 

`proc <args> <body>`
- Define a Tcl procedure. This must be a legal Tcl procedure definition. 
Arbitrary Tcl procedures can be embedded in the tclmakefile. Note that tclmake 
does not recognize arbitrary Tcl commands in the tclmakefile, only full proc 
definitions are recognized. For example, you cannot use commands like: `set 
onething anotherthing`

Comment lines can be added using a `#` character at the beginning of the line.