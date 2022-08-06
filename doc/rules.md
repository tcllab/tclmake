# Rules

tclmake recognizes rules in a subset of make syntax. The types of rules 
recognized are:

- Simple rules
- Phony targets
- Pattern rules
- Suffix rules
- Double-colon rules
- Option rules 

## Simple rules

Simple rules are rules that contain a colon but do not contain a percent sign.

    tclIndex: $(TCL_SRCS)

Targets are to the left; dependencies to the right. There can be an arbitrary 
number of either. Wild-cards, such as `*.tcl` can be used on either side of the 
colon.

If a target does not exist, or if any of the dependencies is newer than any of 
the targets, then that target is out of date, and the rule's command will be 
executed to update it. If any dependency is itself a target (in another rule), 
then the dependencies will be chained to determine if the dependency itself 
needs updating,

## Phony targets

If a target is not the name of a file, then it is what is called a "phony 
target". This allows rules to act almost as procedure calls. For example, a 
first rule in a tclmakefile may be:

    all: tclIndex sources

When tclmake attempts to update the goal **all**, it looks for a file named 
**all**. If it doesn't find one, it recursively attempts to update the 
dependencies **tclIndex** and **sources**. The effect is exactly the same as if 
**tclIndex** and **sources** had been the goals in the first place.

## Pattern rules

A pattern rule uses the character `%` as a place-holder to match patterns. The 
general form of this rule is:

    targets : target-pattern  : dep-pattern 

For example, we might have the rule:

    $(JAVA_CLASSES): %.class : %.java

Suppose the name **hype.class** is included in the variable **JAVA_CLASSES** 
and the **hype.class** file becomes a goal.  Then tclmake will match the 
pattern `%.class` against it, and use **hype.java** as its dependency.

The above is a case where the target files are explicitly listed.  More often 
than not, the initial target list will be omitted, as in:

    %.class : %.java

In this case, tclmake will try matching the pattern `%.class` against any 
target that becomes a goal. The **hype.class** file would then be implicitly 
accepted as a target for the rule.  This is less efficient, but often more 
convenient.

### Reverse pattern match rule

tclmake recognizes a special case: a pattern rule that looks like the explicit 
type, but instead of the user having to supply a list of target files, the rule 
supplies them by using the dependency pattern to do a glob file search.

For example, consider the rule:

    sources: % :: SCCS/s.%
        exec sccs get $<
        
In the ordinary case of an explicit pattern match rule, the target **sources** 
would be used to construct a target-pattern value **sources** and a dep-pattern 
value **SCCS/s.sources**.  If there is no file called **SCCS/s.sources**, then 
tclmake goes into a special behavior: it takes the dep-pattern, substitutes the 
`%` for a `*`, then does a glob search for `SCCS/s.*`.  Each file name returned 
from the search will be processed independently in a loop with the 
target-pattern used as the target and the file name used as the dependency.  
The command associated with the rule will be run once for each file name 
returned.

Note that for the special behavior to be enabled, the rule must be a terminator 
rule with double colons separating the target-pattern from the dep-pattern.  
See **Double-colon rules** below.

This special behavior can be used for example to compile all C files in a 
directory into object files, without having to list the C files explicitly:

    all_objs : %.o :: %.c
        exec cc -c $< -o $@

## Suffix rules

A suffix rule consists of two concatenated file suffixes. For example:

    .java.class:

A suffix rule is an older form of rule. This rule is equivalent to the rule

    %.class : %.java

## Double-colon rules

Any rule can have a double-colon instead of a single colon, as in the example

    %.tcl :: SCCS/s.%.tcl

The double-colon means that this rule is a terminator rule. tclmake will not 
chain dependencies in terminator rules. In this example, this means that, if 
tclmake finds, say, a file **foo.tcl**, but no file named **SCCS/s.foo.tcl**, 
it will not attempt to update a target named **SCCS/s.foo.tcl**, which can 
never be a target.

In other words, use the double-colon when a dependency is a file that must 
exist, and cannot be produced from other files.

## Option rules

One of the few extensions tclmake makes to regular make is the ability to 
define command-line options in the tclmakefile itself. To do so, simply define 
a rule that has targets beginning with a leading dash, and with no 
dependencies. If any of those targets are specified on the command line, the 
rule will be run after updating all other targets.

The `--recursive` and `--packages` command-line options are defined in this 
way. See [Recursive tclmakes](./recursion.md) for examples. 

For example, the following rule could be defined:

    --notify-ci :
        exec mail -s "Compilation completed" CI@example.com < /dev/null

It could be used from the command line like so:

    % tclmake --notify-ci build_program
    
tclmake treats `--notify-ci` as a goal specified on the command line just like 
any other, except that since its name identifies it as an option goal it is 
guaranteed to be evaluated last, after all other goals.

An option rule can also be specified as a dependency in a tclmakefile like any 
other rule.  The following could be defined:

    deploy_program : build_program --notify-ci

    build_program : $(build_objects)
        exec CompileProgram.sh $^
        
and if **deploy_program** were specified as a goal, the **build_program** goal 
would be updated, then the **--notify-ci** option goal command would send the 
notification email.

Unlike other targets, an option rule target is never marked as updated, so an 
option rule can be used in multiple places in a dependency chain, and its 
command will be executed each time the option rule is included in a target's 
dependencies.

## MAKE_UPDATE procedure

The up-to-date status of a target based on its timestamp relative to its 
dependencies can be overridden.  The procedure `MAKE_UPDATE` is available to be 
called by any Tcl script in the tclmakefile.  It takes two arguments: a target 
name and a conditional expression.  If the conditional evaluates to true, the 
update command of the specified target is run regardless of whether the target 
is out of date with respect to its dependencies.  If the expression is false, 
the target will not be updated even if it is out of date.

The `MAKE_UPDATE` proc allows definition of any criteria for updating a target, 
beyond simply comparing file modification times.  If `MAKE_UPDATE` is called in 
the command of one of the target's dependencies, when dependency updating 
is done and it's time for the target to be updated, the target's update script 
will be run or not based on the value of the conditional expression passed to 
`MAKE_UPDATE` when it was called.

## Special characters in rules

GNU make does not permit colons in names of targets or dependencies, because 
they would interfere in parsing of rule syntax.  This can be problematic for 
Windows users, where filenames like **C:/Users** are common.

tclmake also does not permit colons in target or dependency names, but a colon 
can be replaced with a pipe character (`|`).  Dependencies will be evaluated 
correctly, and the actual file name with colons included will be used where 
appropriate (for example in setting the values of automatic variables), so the 
correct file names can by used in a rule's command script.

GNU make also does not permit spaces in file names.  But tclmake handles 
targets and dependencies in a rule as Tcl lists, thus any special characters, 
including spaces, can be included as long as they are quoted or bracketed 
consistent with Tcl list format rules.

For example, the following would be valid in a tclmakefile:

    {C|/Program Files/myprogram.exe} : program.c program.h
        exec compile.bat $^
        file copy -force program.exe {$@}