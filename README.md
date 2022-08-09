# tclmake 2022, v. 2.3

tclmake is not meant to be a clone of standard make, but it borrows many
features and adds a few useful features of its own. Anyone with experience 
using standard make should find it easy to pick up and use tclmake.

The chief difference is that in tclmake the logic for updating a target is 
expressed as a single Tcl script, rather than a sequence of discrete shell 
commands.

If you've ever struggled with writing a GNU makefile and thought, 'this would 
go a lot easier if I could write the update logic in a dynamic language', then
tclmake may be the tool for you.

------

What a tclmake makefile looks like:

    # Value of MAKE_INIT var is treated as a Tcl script and evaluated after file
    # is parsed but before goal updating:
    MAKE_INIT = make_init
    
    # Make variables defined:
    SDX = lib/sdx.kit
    RUNTIME = bin/basekit
    
    # Procs can be defined and called within rule recipe script:
    proc make_init {} {
    	set ::env(PATH) $::env(PATH):[file norm ~/bin]
    }
    
    # An option rule:
    --test-wrap :
    	# Automatic variables like "$!" inserted into Tcl script by macro
    	# substitution before evalution, as GNU Make does:
    	set target "$!"
    	if {![file exists $target]} return
    	set vfs [file root $target].vfs
    	lassign [exec basekit $(SDX) version $target] date time version
    	lassign [exec basekit $(SDX) version $vfs] vfsdate vfstime vfsversion
    	# Proc MAKE_UPDATE drives whether a target is updated based on given
    	# conditional, independent of file mtimes of prerequisites:
    	MAKE_UPDATE $target [list $version ne $vfsversion]
    
    # GNU make style pattern rules:
    %.kit : %.vfs --test-wrap
    	@puts "Wrapping $@:"
    	# Make vars substituted into Tcl script. If a var is undefined, an empty
    	string is used:
    	exec basekit $(SDX) wrap "$@" -vfs "$<" $(WRAP_OPTIONS)
    
    %.exe : %.kit
    	if {"$(RUNTIME)" eq ""} {
    		error "Make variable RUNTIME must be defined to make starpack."
    	}
    	@puts "Wrapping $@:"
    	set vfs [file root "$@"].vfs
    	exec basekit $(SDX) wrap "$@" -vfs $vfs -runtime "$(RUNTIME)" $(WRAP_OPTIONS)

------

# Feature highlights

- Like GNU make, tclmake features simple and pattern rules with targets and 
prerequisites, make variables and automatic variables with values inserted by 
macro substitution.

- tclmake can be used as a stand-alone command line program, or as a package
within another Tcl project.

- tclmake allows you to define Tcl procs in the makefile, allowing you to 
organize complex update logic within your makefile.  You can also source Tcl 
code files and load packages from within a makefile

- You can define a **MAKE_INIT** make variable to contain a Tcl script.  If the 
variable exists after the makefile has been parsed but before updating of 
targets begins, this script will be evaluated.  The script can for example 
change directories, load packages or otherwise initialize the environment.

- If a make variable defintion line begins with the keyword **MAKE_EVAL**, the 
variable value is treated as Tcl code, and command and variable substitution is 
done on it, and the result stored in the variable.  Thus Tcl can be used for 
many customizations in a makefile, rather than GNU make's bespoke programming 
language.

- The procedure MAKE_UPDATE is available to be called by any Tcl script in the 
makefile.  The MAKE_UPDATE proc evaluates a conditional and applies its result 
to a target; the boolean conditional result determines if a target is updated 
or not.  This allows you to define any criteria for updating a target, beyond 
simply comparing file modification times.
  
- You can turn recursive dependency-updating on or off on the command line.  
  - The option '--update' will force all targets in a dependency chain to be 
updated, regardless of whether they are out of date.  This is handy for 
testing, for example, or when new files of unknown timestamp are merged into a 
project, because it will cause update commands of all of a goal's dependencies 
to be run.
  - The option '--terminator' will force all specified targets to be treated as 
terminator rules; that is, for the specified target a dependency chain won't be 
followed. This is handy, for example, for testing an install goal without 
triggering a complete rebuild of a project.

# Motivation

I used to like using GNU make, not just for building software, but also for 
defining and managing complex data processing workflows.  At first glance, a 
makefile's definitions of targets, dependencies and logic are intuitive and 
easy to grasp.  But complexities quickly set in.  There are many obscure 
features to create brittle bespoke solutions to hard-to-handle cases.  GNU make 
has its own (seemingly ad hoc) programming language.  The protocol for escaping 
special characters appears incomplete.  I know there are shell commands I 
wanted to use in a makefile but I just could not find ways to escape all the 
special characters to make's satisfaction.  Perhaps most surprising, GNU make 
simply won't accept spaces in target or prerequisite names, no matter what 
escaping or quoting mechanism you think or hope should work.  So it's 
impossible to use arbitrary collections of files as inputs.  All filename 
inputs to a GNU makefile have to be known and vetted in advance.

tclmake simply evaluates the targets and dependencies of a rule as lists, and 
spaces and special characters are just fine as long as the list elements are 
properly formatted.  Just about any sequence of characters can be escaped and 
incorporated into a rule as long as you are diligent and observe Tcl's 
clearly-defined parsing rules. When Tcl's ability to escape and process 
arbitrary inputs is compared to a tool as widely-adopted and venerated as GNU 
make, it's a testament to just what an accomplishment Tcl's syntax is.

# Docs 

  1. [Introduction](./doc/introduction.md)
  2. [Invoking tclmake](./doc/running.md)
  3. [Reading the makefile](./doc/parsing.md)
  4. [Variables](./doc/variables.md)
  5. [Rules](./doc/rules.md)
  6. [Commands](./doc/commands.md)
  7. [Recursive tclmakes](./doc/recursion.md)
  8. [A complete example](./doc/example.md)
  9. [Limitations](./doc/limitations.md)


# License

MIT License.

# Thanks

Thanks to John Reekie, who wrote the original tclmake, and released it in 1998 
as part of the Ptolemy project at Berkeley.