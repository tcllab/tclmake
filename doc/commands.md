# Commands

The command for any rule is just a Tcl script. The command must be on the line 
immediately after a rule, and must be indented by at least one space or tab. 
The command ends at the first blank line or line that has a character at the 
start of the line.

Unlike GNU make, which evaluates each line in a command separately in its own 
process, tclmake evaluates the command as a whole.  So a variable that is 
defined on one line, for example, can be referenced in a later line.

Also unlike GNU make, which requires that tabs be used to indent the lines in a 
command, tclmake accepts any whitespace for indenting.

If a line starts with the character `@`, then the Tcl command starting on that 
line will not be echoed to the console. (Note that `@` can be used only as the 
first character of a line that starts a new Tcl command that is not within 
another Tcl command.)

The command will have any make-variables substituted into it. The command will 
also have the following automatic variables substituted:

`$@`
 - The name of the target that is being updated. In the tclIndex example, this 
variable will be **tclIndex**. 
 
`$!`
 - The name of the target that is being updated that caused this target to be 
updated. This is like going "up the call stack," and is used only in very 
special circumstances (see [Recursive tclmakes](./recursion.md)). This variable 
is unique to tclmake. 
 
`$<`
 - The name of the first dependency. In the tclIndex example, this variable 
will be the first file in **TCL_SRCS**. 
 
`$?`
 - The names of the dependencies that have been updated before the target. In 
the tclIndex example, this variable will be the files in **TCL_SRCS** that are 
newer than **tclIndex**. 
 
`$^`
`$+`
 - The names of all dependencies. In the tclIndex example, this variable will 
be the value of **TCL_SRCS**. 
 
`$*`
 - The stem of a pattern-match rule -- that is, the part of the file name that 
matched the `%` symbol. 
 
 All commands are executed in the global namespace of a special interpreter 
created at the beginning of the goal evaluation process, which is separate from 
the interpreter executing the tclmake program code.  All global variables 
created by the execution of a command in the special interpreter are deleted 
when the command is finished, to prevent collision of variable values between 
commands.  If a user wishes to persist state from execution of one command to 
another, it can be done by other means that avoid use of global variables, such 
as creating special namespace variables.  However, doing so goes against the 
typical assumption of statelessness of individual make commands, and should be 
done with caution.
 
 The working directory is also reset each time a command completes, to the 
value it had when the command was first called.  Thus any directory changes 
done within the command are reverted.