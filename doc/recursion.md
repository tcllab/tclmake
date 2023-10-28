# Recursive tclmakes

tclmake supports recursion in the same way that make does. In addition, its 
option-rules can be used to avoid having to write recursion explicitly for 
every target.

Here is a command that performs a recursive clean. It assumes that there is a 
make-variable named **DIRS**:

    clean:
		@if { [glob -nocomplain *~ core #*# ,*] == "" } {
    	    break
    	}
    	eval file delete [glob -nocomplain *~ core #*# ,*]
		@foreach dir {$(DIRS)} {
    	   if { [file isdirectory $dir] && [file executable $dir] } {
		      cd $dir
    		  $(MAKE) $(MFLAGS) $(MAKEVARS) clean
    		  cd $(MAKEDIR)
    	    }
    	}

For each sub-directory in the **DIRS** make-variable, tclmake will call itself 
recursively. (Each recursive call creates a new Tcl interpreter, to ensure that 
there are no problems with sub-tclmakes corrupting global state.)

Although this works, it means that every rule that is to be recursively 
processed needs to be written this way. tclmake has a better solution: use an 
option-rule (see [Option rules](./rules.md)). For recursion, the option-rule 
needed is this:

    -r --recursive:
		@foreach dir {$(DIRS)} {
    	    if { [file isdirectory $dir] && [file executable $dir] } {
    		  cd $dir
    		  $(MAKE) $(MFLAGS) $(MAKEVARS) $!
    		  cd $(MAKEDIR)
    	    }
    	}

Now, the recursion can be invoked in one of two ways. First, it can simply be 
specified on the command line, as in:

    tclmake --recursive clean

Second, it can be added to any rule as a dependency. Thus, the recursive 
"clean" rule above is written as

    clean: --recursive
		@if { [glob -nocomplain *~ core #*# ,*] == "" } {
    	    break
    	}
    	eval file delete [glob -nocomplain *~ core #*# ,*]

In this case, `tclmake clean` will recursively clean directories.

Note the use of the `$!` automatic variable in the **--recursive** rule.  It is 
defined as the preceding target that caused the current target to be updated.
In the example above the variable is given the value **clean**.
