# Tclmake: a A simple Tcl-only make-like utility
#
# @Author: John Reekie
#
# @Version: @(#)main.tcl	1.6 05/14/98
#
# @Copyright (c) 1997-1998 The Regents of the University of California.
# Changes Copyright (c) 2022 Stephen E. Huntley
# All rights reserved.
#
# Permission is hereby granted, without written agreement and without
# license or royalty fees, to use, copy, modify, and distribute this
# software and its documentation for any purpose, provided that the above
# copyright notice and the following two paragraphs appear in all copies
# of this software.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
# THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
# PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
# CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
# ENHANCEMENTS, OR MODIFICATIONS.
# 
#                                        PT_COPYRIGHT_VERSION_2
#                                        COPYRIGHTENDKEY
#######################################################################


#######################################################################
package require Tcl 8.5
#### variables
#
# Set these here so I have a reason to write a comment...

# The command-line flags
array set _flags {
    debug 0
    file {}
    help 0
    packages 0
    recursive 0
    silent 0
    terminal 0
    update 0
}

# The goals: targets that need to be updated
set _goals {}

# The option goals
set _optiongoals {}

# The targets (left-hand-side) of rules
array set _target {}

# The dependencies (right-hand-side) of rules
array set _depend {}

# The corresponding commands
array set _command {}

# The make-variables
array set _vars {}

# A unique counter for rule ids
set _unique 0

# The array of up-to-date targets
#array set _uptodate {}
array set _updated {}

# A flag that says if a rule is terminal
array set _terminal {}

# The makefiles "used" for variable definitions.
set _makefiledata ""

# Unrecognized options
set _unrecognized {}

#######################################################################
#### tclmake
# The main procedure. This procedure creates an interpreter
# within which the make for the current directory can run, and
# then loads the package into that directory and so on. The first
# argument is the name of the directory to run in.
# 
proc tclmake {args} {
    global env

    # Create a new interpreter
    set interp [interp create]

    # Give the interpreter access to the auto_mkindex function
    # in _this_ interpreter. This is so the itcl version
    # runs (if we are running in itclsh).
    $interp alias auto_mkindex auto_mkindex

    # Execute the main procedure.
    set script {
	lappend auto_path $env(TCLMAKE_LIBRARY)
	if {[info exists env(TCLLIBPATH)]} {
		lappend auto_path [lindex [array get env TCLLIBPATH] 1]
	}

	package require tclmake

	# Set variables and call the _tclmake procedure
	set _vars(MAKE) "tclmake"
	set _vars(MAKEDIR) [pwd]
	set _vars(MAKEVARS) ""
	set _vars(MFLAGS) ""
	eval _tclmake [lrange [list $args] 0 end]
    }
    set script [subst -nocommands $script]
    
    try {
        $interp eval $script
    } finally {
        interp delete $interp
    }
}

#######################################################################
#### _tclmake
# The real main tclmake procedure. This procedure processes options,
# initiates the file parsing and goal resolution, and
# performs the recursive tclmake.
# 
proc _tclmake {args} {
    global _flags _goals _optiongoals _vars _makedata
    global _target _depend _unrecognized _updated
    global env
    global makefile_interp

    # Print the current directory
    puts [pwd]

    # Process command-line arguments
    if [eval _processCommandLine $args] {
	return 1
    }

    # Create sub-interpreter in which to execute all makefile commands
    set makefile_interp [interp create]
    $makefile_interp alias auto_mkindex auto_mkindex
    $makefile_interp alias MAKE_UPDATE MAKE_UPDATE
    $makefile_interp alias tclmake tclmake

    # Find the makefile
    set file ""
    if { $_flags(file) != "" } {
	set file $_flags(file)
    } elseif [file exists makefile.tmk] {
	set file makefile.tmk
    } elseif [file exists Makefile.tmk] {
	set file Makefile.tmk
    }

    # If we have no file, try getting it from the makefile
    if  { $file == "" } {
	if [file exists makefile] {
	    set file makefile
	} elseif [file exists Makefile] {
	    set file Makefile
	}
	if { $file != "" } {
	    # Read it
	    _useMakefile $file
	    if [catch {set file [_getVar TCLMAKEFILE]}] {
		global _makefiledata
		set _makefiledata ""
		set file ""
	    }
	}
    }
    # If we still don't have a file, see if there is
    # an environment variable named MAKELIB and if there is
    # a makefile there
    if { $file == "" } {
	if [info exists env(MAKELIB)] {
	    if [file exists [file join $env(MAKELIB) default.tmk]] {
		set file [file join $env(MAKELIB) default.tmk]
	    }
	}
    }

    # If still not, then look in TCLMAKE_LIBRARY
    if { $file == "" } {
	set file [file join $env(TCLMAKE_LIBRARY) mk default.tmk]
    }
    
    set file [file dir [file norm [file join $file __dummy__]]]
    
    if $_flags(debug) {
	puts "Reading file \"$file\""
    }
    
    # Define special make variable with pathname of original makefile
    set _vars(MAKEFILE) $file

    # Parse it
    _parseFile $file

    # Check that all command-line options have now been
    # defined
    if { $_unrecognized != "" } {
	puts "Unrecognized command-line options: $_unrecognized. Continuing..."
    }
    # Get a default goal if needed
    if { $_goals == {} && [array size _target] != 0 } {
	# Get the default goal. Only works for simple rules.
	# First two rules skipped because they are hard coded into program
	foreach {target_index} [lrange [lsort -dic [array names _target]] 2 end] {
		set _goals [string trim [lindex $_target($target_index) 0]]
		if {$_goals ne {}} {break}
	}
    }

    # Makefile may define special var containing Tcl script, eval it in
    # sub-interpreter before starting to update goals
    if {[info exists _vars(MAKE_INIT)]} {
	if $_flags(debug) {
		puts "Executing MAKE_INIT command: $_vars(MAKE_INIT)"
    	}
       $makefile_interp eval [lrange [_substVars $_vars(MAKE_INIT)] 0 end]
    }

    # Evaluate the goals. Options get processed after regular goals
    if $_flags(debug) {
	puts "Processing rules..."
    }
    
    # Eliminate all redundantly-listed goals
    set allgoals [concat $_goals $_optiongoals]
    set allgoals [dict keys [dict create {*}[concat {*}[lmap v $allgoals {set v [list $v 0]}]]]]

try {
    foreach goal $allgoals {
	_updateTarget $goal
    }
} trap {missing_target} {} {
    
} finally {
    cd $_vars(MAKEDIR)
}

}

#######################################################################
#### _processCommandLine
# Extract command options into the _flags array. If an option
# is unrecognized, place it into the _unrecognized list
# for later recognition.
# 
proc _processCommandLine {args} {
    global _flags _goals _optiongoals _vars _unrecognized

    set optiongoals {}
    
    # Duplicate GNU Make special variable containing goals specified on
    # command line
    lappend _vars(MAKECMDGOALS)

    # Process command-line args
    while { $args != "" } {
	set option [lindex $args 0]
	set args [lreplace $args 0 0]

	if ![string match {-*} $option] {
	    if [regexp {^([^ =]*)=(.*)$} $option _ name value] {
	        # Got a variable value
	        set _vars($name) $value
	        lappend _vars(MAKEVARS) $option
	    } else {
	        # Got a goal
	        lappend _goals $option
	        lappend _vars(MAKECMDGOALS) $option
	    }

	} else {
	    set optionval {}
	    switch -exact -- $option {
		"-d" -
		"--debug" {
		    set _flags(debug) 1
		}
		"-f" -
		"--file" {
		    set optionval [file norm [lindex $args 0]]
		    set _flags(file) $optionval
		    set args [lreplace $args 0 0]
		}
		"-h" -
		"--help" {
		    _help
		    return 1
		}
		"-s" -
		"--silent" -
		"--quiet" {
		    set _flags(silent) 1
		}
		"-t" -
		"--terminator" {
		    set _flags(terminal) 1
		}
		"-u" -
		"--update" {
		    set _flags(update) 1
		}
		"-p" -
		"--packages" -
		"-r" -
		"--recursive" {
		    
		}
		default {
		    # Unknown option. What we do here is add it
		    # to the list of unrecognized options, so that
		    # we know if it doesn't get defined. We also add
		    # it to the list of option goals, so that it will
		    # get run.
		    lappend _unrecognized $option
		    lappend _optiongoals $option
		    lappend _vars(MAKECMDGOALS) $option
		}
	    }
	    append _vars(MFLAGS) " $option " {*}$optionval
	}
    }
    
    if {$_flags(terminal) && $_flags(update)} {
        puts "Can't set both --terminator and --update flags"
        return 1
    }
    return 0
}

#######################################################################
#### _help
# Print help information. To generate this quickly, open the
# documentation in netscape and just cut and paste
# the relevant text!
# 
proc _help {} {
    puts "tclmake, version 2.0 Usage:"
    puts {
-d 
--debug 
      Print debugging information. 
-f filename 
--file filename 
      Use this file as the tclmakefile. 
-h 
--help 
      Print out this list of options. 
-p 
--packages 
      Recursively process directories that contain a pkgIndex.tcl file.
      This option is unique to tclmake 
-r 
--recursive 
      After processing the current directory, tclmake will process
      sub-directories (see below for more information). This option is
      unique to tclmake 
-s 
--silent 
--quiet 
      Print no information at all to stdout or stderr. 
-t 
--terminator
      Treat rules for all given targets as terminator rules (deactivate 
      recursive updating).
-u 
--update 
      Ignore timestamps and update targets even if they're not out of date. 
}
}

#######################################################################
#### _error
# Handle an error. If the debug flag is off, print the message
# and exit; if it is on, print the stack trace as well.
# 
proc _error {msg {stack {}}} {
    global _flags
    if $_flags(debug) {
	if { $stack == "" } {
	    global errorInfo
	    set stack $errorInfo
	}
	error $msg $stack
    } else {
	puts "Fatal error: \n$msg"
	exit
    }
}

#######################################################################
#### _catcherror
# Evaluate a script and generate an error if it fails.
# 
proc _catcherror {script} {
    if [catch {uplevel $script} msg] {
	global errorInfo
	_error $msg $errorInfo
    }
}

#######################################################################
#### MAKE_UPDATE
# Procedure aliased into sub-interpreter and callable by any command in
# makefile.  Forces override of mtime-based update decision.
# 
# Arg 'target' is any target value that may come up for update
# 
# Arg 'condition' is a conditional expression; if it evaluates to 'true', when
# the target comes up for evaluation, it will be updated regardless of state
# of dependencies.  If it is 'false' it will not be updated even if out of date
# 
proc MAKE_UPDATE {target condition} {
	global _updated
	set _updated($target) "MAKE_UPDATE 1"
	if $condition {
		set _updated($target) "MAKE_UPDATE 0"
	}
}
