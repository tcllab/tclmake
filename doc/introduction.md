# Introduction

tclmake works on exactly the same principles as make. A makefile contains rules, which specify which files are used to produced which other files, and commands, which are executed to update files. Here is a sample rule and command:

    tclIndex: main.tcl parse.tcl update.tcl
        auto_mkindex [pwd] main.tcl parse.tcl update.tcl

The files on the left-hand side of a rule are called targets, and those on the right are called dependencies. In this case, the target is **tclIndex**, and the dependencies are the three Tcl files.

The job of tclmake is to see if any of the targets are out of date, and if they are, to update them. For example, if tclmake is invoked with

    tclmake tclIndex

then tclmake looks at the modification dates of **tclIndex** and the three Tcl files. If any of the Tcl files is more recent than **tclIndex**, or if **tclIndex** does not exist, then tclmake executes the command, which updates **tclIndex**.

The targets given on the command line when tclmake is invoked are called the goals, since these are the targets that tclmake will try to update. If no goals are given on the command line, then tclmake will use the targets of the first rule in the makefile as its goals.

Dependencies are typically chained. For example, suppose that each Tcl file also depends on some other file, such as a source-code control file. In that case, we might have a rule like this:

    %.tcl :: SCCS/s.%.tcl
        exec sccs get $<

This rule says that any file with the ".tcl" suffix depends on a file in the **SCCS** directory. (The double-colon is explained in [Double-colon rules](./rules.md).) Suppose we try to make **tclIndex**. tclmake sees that this file depends on **main.tcl**. However, instead of just checking the date of **main.tcl**, it also sees that **main.tcl** depends on **SCCS/s.main.tcl**, so tclmake then checks whether **SCCS/s.main.tcl** is newer than **main.tcl**. If it is, it executes the `sccs` command, and then executes the command that updates **tclIndex**. (If not, then it goes back and compares the file dates of **tclIndex** and **main.tcl**, as before.)

A makefile (or, to distinguish between makefiles for regular make and makefiles for tclmake, a "tclmakefile") thus captures arbitrarily complex dependencies between files; tclmake provides the resolution mechanism that ensures that files are updated or regenerated in the correct order. 