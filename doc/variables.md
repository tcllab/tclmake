# Variables

Variables can be used to simplify makefiles. A variable definition looks like 
this:

    FOO = bar baz

Backslashes can be used to continue lines:

    FOO = \
         bar \
         baz

A variable substitution looks like this:

    $(FOO)

A typical use of variables would be something like:

    TCL_FILES = main.tcl update.tcl parse.tcl
    tclIndex: $(TCL_FILES)
            auto_mkindex [pwd] $^

When tclmake processes a rule or a command, it substitutes variable definitions 
wherever possible. In this example, the effect is exactly the same as for the 
rule in the [Introduction](./introduction.md). The variable `$^` stands for all 
the dependencies of the rule -- see [Commands](./commands.md).

Variables are defined recursively, as in make. For example, in the following,

    FOO = $(BAR) foo!
    BAR = oh

the value of **FOO** will be "oh foo!".

Environment variables can be referenced in the same way. A variable defined in 
a tclmakefile or on the command line will override the value given by the 
environment. tclmake can also read variable definitions from regular makefiles, 
with a command such as

    use makefile
    
If a variable is used in a makefile that has not been defined and no 
corresponding environment variable exists, a debug warning will be generated 
and the variable will be defined as the empty string.
    
## Pre-defined variables

tclmake defines some variables automatically:

**MAKE**
- The command used to invoke it. This is always set to "tclmake", so that it 
can be used to run a sub-make. 

**MAKEDIR**
- The directory in which tclmake is running. 

**MFLAGS**
- The flags passed to tclmake on the command line. 

**MAKEVARS**
- The variables passed to tclmake on the command line. 

**MAKEFILE**
- The fully-normalized pathname of the tclmakefile.

**MAKECMDGOALS**
- The goals specified in the command line.

## MAKE_INIT variable

If a variable named **MAKE_INIT** is defined after parsing the tclmakefile, it 
is assumed that its value is a valid one-line Tcl script and is evaluated 
before updating of targets begins.  The script can for example change 
directories, load packages or otherwise initialize the environment.  The 
simplest way to use this feature is just to define an initialization proc and 
then set the **MAKE_INIT** variable to the name of the proc plus any arguments 
it takes.

## Dynamic variable definition

If the value in a make variable defintion line is enclosed in square brackets, 
the value is treated as Tcl code, the code is evaluated, and the result is 
stored in the variable.

For example, the following could be written in a tclmakefile:

    TCL_FILES = [glob *.tcl]
    
The `glob` command would be evaluated and the result stored in the variable 
**TCL_FILES**

If you want to store a literal value in a variable that is enclosed in square 
brackets, you can do something like the following:

    TCL_FILES = \[glob *.tcl]
    
The variable **TCL_FILES** will then contain the literal value `[glob *.tcl]`

## MAKE_EVAL keyword

For the sake of backward compatibility, a variable definition line can begin 
with the keyword **MAKE_EVAL**, in which case the line will be dynamically 
defined as decribed above, e.g.:

    MAKE_EVAL TCL_FILES = [glob *.tcl]
    
will cause the value of **TCL_FILES** to be the result of the glob command. It 
may be desirable to use the keyword for clarity as to the dynamic nature of the 
variable definition.

------

tclmake does not support non-recursively-defined variables, as in the := 
definitions of GNU make. 

