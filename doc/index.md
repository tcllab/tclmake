# tclmake -- a Tcl-only make-like utility

tclmake is a simple make-like utility written entirely in Tcl. It reads files written in a subset of regular (GNU) make, but with the commands for each rule written in Tcl.

tclmake is not meant to be a clone of standard make, but it borrows many
features and adds a few useful features of its own. Anyone with experience 
using standard make should find it easy to pick up and use tclmake.

The chief difference is that in tclmake the logic for updating a target is 
expressed as a single Tcl script, rather than a sequence of discrete shell 
commands.

For example, a rule and command might look like:

    tclIndex: main.tcl parse.tcl update.tcl
        auto_mkindex [pwd] main.tcl parse.tcl update.tcl
        
What a tclmake makefile looks like:

    # Value of MAKE_INIT var is treated as a Tcl script and evaluated after file
    # is parsed but before goal updating:
    MAKE_INIT = make_init
    
    # Make variables defined:
    SDX = lib/sdx.kit
    RUNTIME = bin/basekit
    
    # Procs can be defined and called within rule command script:
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

Like GNU make, tclmake features simple and pattern rules with targets and 
prerequisites, make variables and automatic variables with values inserted by 
macro substitution.

tclmake can be used as a stand-alone command line program, or as a package
within another Tcl project.

Documentation Contents:

  1. [Introduction](./introduction.md)
  2. [Invoking tclmake](./running.md)
  3. [Reading the makefile](./parsing.md)
  4. [Variables](./variables.md)
  5. [Rules](./rules.md)
  6. [Commands](./commands.md)
  7. [Recursive tclmakes](./recursion.md)
  8. [A complete example](./example.md)
  9. [Limitations](./limitations.md)

Copyright © 1998, The Regents of the University of California. All rights reserved. Last updated: 05/11/98. Author: John Reekie.

Copyright © 2022, Stephen E. Huntley.