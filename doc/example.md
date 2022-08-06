# A complete example

To put all this together, here is a complete example.  This was the original tclmakefile for preparing a release of the package.

    # Directories to recurse in
    DIRS = doc bin
    
    # TCL files
    TCL_SRCS = \
    	main.tcl \
    	parse.tcl \
    	update.tcl
    
    # Update the Tcl index file
    tclIndex: $(TCL_SRCS)
            auto_mkindex $(MAKEDIR) $^
    
    # Clean the directory
    clean:
		@if { [glob -nocomplain *~ core #*# ,*] == "" } {
    	    break
    	}
    	eval file delete [glob -nocomplain *~ core #*# ,* dist/* dist]
    
    # Make sources from sccs
    % :: SCCS/s.%
    	exec sccs get $@
    
    # Explicit rule for making sources
    sources: % :: SCCS/s.%
    	exec sccs get $@
    
    # The option-rule for recursion in directories
    -r --recursive:
		@foreach dir {$(DIRS)} {
    	    if { [file type $dir] == "directory" && [file executable $dir] } {
    		  set cwd [pwd]
    		  cd $dir
    		  $(MAKE) $(MFLAGS) $(MAKEVARS) $!
    		  cd $cwd
    	    }
    	}

# Another example

The below example shows some of the newer features of tclmake.  The pattern rules cause a new tclkit to be wrapped based on whether there are new edits to its corresponding unwrapped starkit.  Since an unwrapped starkit may contain many files, there is no one file that can be used as a dependency such that a new file modification time would make the tclkit out of date.  Instead, an option rule is used to generate version hashes (using the "sdx" package) of the tclkit and the unwrapped starkit, and within the command script of the option rule the procedure `MAKE_UPDATE` is used to compare version hashes and schedule the tclkit to be updated only when the versions differ.

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
    	# Make vars substituted into Tcl script. If a var is undefined, an
    	# empty string is used:
    	exec basekit $(SDX) wrap "$@" -vfs "$<" $(WRAP_OPTIONS)
    
    %.exe : %.kit
    	if {"$(RUNTIME)" eq ""} {
    		error "Make variable RUNTIME must be defined to make starpack."
    	}
    	@puts "Wrapping $@:"
    	set vfs [file root "$@"].vfs
    	exec basekit $(SDX) wrap "$@" -vfs $vfs -runtime "$(RUNTIME)" $(WRAP_OPTIONS)
    	
The option rule **--test-wrap** uses the `$!` automatic variable to generate version stamps for a wrapped and unwrapped starkit without having to know its name specifically, and the `MAKE_UPDATE` proc is used to compare the version stamps and mark if the wrapped starkit needs to be regenerated.

Since an option rule is never marked as updated, the **--test-wrap** rule is 
generic, and can be used as a prerequisite for any number of starkits in a 
makefile.  Thus it can function as a sort of 'mixin', to borrow an OOP term, 
that enhances the function of the object it is associated with.