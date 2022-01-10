# tclmake 2022, v. 2.0

tclmake is not meant to be a clone of standard make, but it borrows many
features and adds a few useful features of its own. Anyone with experience 
using standard make should find it easy to pick up and use tclmake.

The chief difference is that in tclmake the logic for updating a target is 
expressed as a single Tcl script, rather than a discrete sequence of shell 
commands.

If you've ever struggled with writing a GNU makefile and thought, 'this would 
go a lot easier if I could write the update logic in Tcl', then tclmake may be 
the tool for you.

This file is meant to be an introduction and a supplement to the original docs, 
which are still valid as to the features that existed up to the point of the 
first release.

# Feature highlights

What a tclmake makefile looks like:

    MAKE_INIT = make_init
    SDX = lib/sdx.kit
    RUNTIME = bin/basekit
    
    proc make_init {} {
    	set ::env(PATH) $::env(PATH):[file norm ~/bin]
    }
    
    --test-wrap :
    	set target "$!"
    	if {![file exists $target]} return
    	set vfs [file root $target].vfs
    	lassign [exec basekit $(SDX) version $target] date time version
    	lassign [exec basekit $(SDX) version $vfs] vfsdate vfstime vfsversion
    	MAKE_UPDATE $target [list $version ne $vfsversion]
    
    %.kit : %.vfs --test-wrap
    	puts "Wrapping $@:"
    	exec basekit $(SDX) wrap "$@" -vfs "$<" $(WRAP_OPTIONS)
    
    %.exe : %.kit
    	if {"$(RUNTIME)" eq ""} {
    		error "Make variable RUNTIME must be defined to make starpack."
    	}
    	puts "Wrapping $@:"
    	set vfs [file root "$@"].vfs
    	exec basekit $(SDX) wrap "$@" -vfs $vfs -runtime "$(RUNTIME)" $(WRAP_OPTIONS)

Like GNU make, tclmake features simple and pattern rules with targets and 
prerequisites, make variables and automatic variables with values inserted by 
macro substitution.

tclmake can be used as a stand-alone command line program, or as a package
within another Tcl project.

## Procs in makefile

tclmake also allows you to define Tcl procs in the makefile, allowing you to 
organize complex update logic within your makefile.  You can also source Tcl 
code files and load packages from within a makefile

## Terminator rules

tclmake has 'terminator' rules, which are similar to GNU make 'terminal' rules. 
Like terminal rules, a terminator rule is defined with a double colon.  Like 
GNU make, all the prerequisites of a a terminator rule's target must exist, and 
no attempt will be made to build a dependency chain to update the prerequisites. 
Unlike GNU make, a terminator rule can be a simple rule or a pattern rule, and 
terminator rules are not all executed or executed independently.  Only the last 
defined rule (terminator or not) for a particular target is executed, and all 
the prerequisites in multiple terminator rules defined for a target are 
gathered as is done with simple rules.

tclmake features a special hybrid 'reverse pattern-match terminator' rule that 
acts as a sort of loop structure; for example:

    move_image_files : $(IMAGE_DIR) :: *.gif *.png *.jp{e,}g
    	file rename $< $@

If the right-hand side prerequisites don't represent any actual files, and if a 
double-colon terminator separator is used on the right-hand side, the 
prerequisites are treated as glob patterns.  The Tcl script supplied with the 
rule is executed individually for each file found to match the glob patterns.

The above rule will find all image files of the specified types, and run the 
script individually for each file, with the '$@' variable defined as 
$(IMAGE_DIR) and '$<' defined as the image filename.

A rule of this type can also use pattern matching (with the '%' treated as a 
'*' for globbing purposes), e.g.:

    all_bins : %.o :: %.c
    	exec cc -c $< -o $@
    	exec cc $@ -o $*

The above rule will find all C source files in the current directory, compile 
them into object files, then each object file will be compiled into an 
executable binary.  That is, progA.c -> progA.o -> progA

If, instead of compiling each C file into an executable, you wanted to compile 
all C files into a single executable, you could do something like the following:

    myprog : all_objs
    	exec cc -o $@ {*}$::myprogNS::allobjs
    	namespace delete ::myprogNS
    
    all_objs : %.o :: %.c
    	exec cc -c $< -o $@
    	namespace eval myprogNS {lappend allobjs $@}

The above two rules will compile all C files into object files, add all object 
file names to a namespace variable, then use the namespace variable to supply 
the list of object files to the compiler to create the final executable.  Note 
that all newly-created global variables are deleted when a rule's script 
completes in order to avoid variable name collisions between rule script 
invocations, but you can get around this by e.g. using namespace variables.

## Option rules

In addition, tclmake has 'option rules', rules whose target name begins with a 
dash.  If specified on the command line, they are guaranteed to be updated 
last; so they are useful for defining a final packaging or CI step.  An option 
rule is never marked as updated, so it can be used multiple times as 
prerequisites of different rules to extend how those rules' targets are updated. 
This is made easier with tclmake's novel '$!' automatic variable, which expands 
to the name of the preceding target whose evaluation has caused the current 
target to be evaluated.

# Features added since tclmake 1.0:

## MAKE_INIT

You can define a 'MAKE_INIT' make variable to contain a Tcl script.  If the 
variable exists after the makefile has been parsed but before updating of 
targets begins, this script will be evaluated.  The script can for example 
change directories, load packages or otherwise initialize the environment.  The 
simplest way to use this feature is just to define an initialization proc and 
then set the MAKE_INIT variable to the name of the proc plus any arguments it 
takes.

## New make variables

Added standard make variables MAKEFILE and MAKECMDGOALS as GNU make does.

## MAKE_UPDATE proc

The procedure MAKE_UPDATE is available to be called by any Tcl script in the 
makefile.  It takes two arguments: a target name and a conditional expression. 
If the conditional evaluates to true, the update script of the specified target 
is run regardless of whether the target is out of date with respect to its 
prerequisites.  If the expression is false, the target will not be updated even 
if it is out of date.

The MAKE_UPDATE proc allows you to define any criteria for updating a target, 
beyond simply comparing file modification times.  If MAKE_UPDATE is called in 
the script of one of the target's prerequisites, when prerequisite updating 
is done and it's time for the target to be updated, the target's update script 
will be run or not based on the result of the MAKE_UPDATE conditional.

The example makefile at the top of this document shows rules for wrapping a 
starkit and creating a starpack.  If you want to know if a wrapped starkit 
needs to be updated from its unwrapped counterpart, you need to know if any 
file in the unwrapped starkit has changed.  In a standard GNU makefile, you'd 
have to include all files in the unwrapped starkit as dependencies, and ensure 
this list of files remains current as your starkit is developed.

Fortunately the sdx package includes a command to create a version stamp for a 
starkit, which operates identically on a wrapped and an unwrapped starkit.  The 
option rule '--test-wrap' uses the '$!' automatic variable to generate version 
stamps for a wrapped and unwrapped starkit without having to know its name 
specifically, and the MAKE_UPDATE proc is used to compare the version 
stamps and mark if the wrapped starkit needs to be regenerated.

Since an option rule is never marked as updated, the '--test-wrap' rule is 
generic, and can be used as a prerequisite for any number of starkits in a 
makefile.  Thus it can function as a sort of 'mixin', to borrow an OOP term, 
that enhances the function of the object it is associated with.

## Command-line options

Two command-line options have been added:

The option '--update' will force all targets in a dependency chain to be 
updated, regardless of whether they are out of date.  GNU make users sometimes 
worry, for example if they import new third-party files into a project, whether 
the timestamps of the new files are out of sync with the project and won't 
cause all targets that make use of the new files to be updated.  The '--update' 
option will assure that all updates will be forced.  It will override any 
settings made by the MAKE_UPDATE proc.

The option '--terminator' will force all specified targets to be treated as 
terminator rules; that is, for the specified target a dependency chain won't be 
followed, only the prerequisites listed for the target will be checked.  For 
example your makefile might have a build rule, and an install rule that lists 
the build products as prerequisites.  After building you may want to deploy 
only the build products to a remote computer and run the install rule.  If you 
use the '--terminator' option on the remote computer, the makefile won't bother 
to look at the prerequisites of the build products and won't try and fail to 
rebuild anything. The install rule will run on the remote computer based simply 
on the state of the build products.  This option will override any settings 
made by the MAKE_UPDATE proc.

The '--recursive' and '--packages' option rules mentioned in the original docs 
are now hard-coded into the program and are always available without having to 
put them in a makefile.  The hard-coded rules can be overridden simply by 
defining new option rules by those names in a makefile.

## Bug fixes

The first two of the three bugs mentioned in the original docs have been fixed. 
The third is arguably not a bug and the behavior is unchanged.

## Internals

The original tclmake created a new interpreter in which to run the program, 
thus the program could be invoked recursively within a makefile without fear of 
interference between invocations.  This is still the case.  But original 
tclmake also ran all makefile Tcl scripts in the global namespace of the new
interpreter, creating a danger of logical collisions and temptation for a 
knowledgeable developer to interfere with the running of the program by 
crafting rule scripts to access the program's internals.  tclmake now creates a 
new sub-interpreter in each invocation, and all Tcl code in the makefile is 
executed in the global namespace of the sub-interpreter.  After a rule script 
is run, all global variables created by the script are deleted to deter 
accidental interference with the next script run.  But if you are clever you can 
preserve state between rule invocations by using namespaces or other such Tcl 
features.

# Motivation

I used to like using GNU make, not just for building software, but also for 
defining and managing complex data processing workflows.  At first glance, a 
makefile's definitions of targets, dependencies and logic are intuitive and 
easy to grasp.  But complexities quickly set in.  There are many obscure 
features to create brittle bespoke solutions to hard-to-handle cases.  GNU make 
has its own (seemingly ad hoc) programming language.  The protocol for escaping 
special characters appears incomplete.  I know there are shell commands I 
wanted to use in a makefile but I just could not find ways to escape all the 
special characters to make's satisfaction (perhaps that was just my lack of 
understanding).  Perhaps most surprising, GNU make simply won't accept spaces 
in target or prerequisite names, no matter what escaping or quoting mechanism 
you think or hope should work.  So it's impossible to use arbitrary collections 
of files as inputs.  All filename inputs to a GNU makefile have to be known and 
vetted in advance.

tclmake simply evaluates the first line of a rule as a list, and spaces and 
special characters are just fine as long as the list elements are properly 
formatted.  Just about any sequence of characters can be escaped and 
incorporated into a rule as long as you are diligent and observe Tcl's 
clearly-defined parsing rules. When Tcl's ability to escape and process 
arbitrary inputs is compared to a tool as widely-adopted and venerated as GNU 
make, it's a testament to just what an accomplishment Tcl's syntax is.

# License

MIT License.

# Thanks

Thanks to John Reekie, who wrote the original tclmake, and released it in 1998 
as part of the Ptolemy project at Berkeley.