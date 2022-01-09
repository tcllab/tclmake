# Tclmake: a A simple Tcl-only make-like utility
#
# @Author: John Reekie
#
# @Version: @(#)main.tcl	1.6 05/14/98
#
# @Copyright (c) 1997-1998 The Regents of the University of California.
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
}

# The goals: targets that need to be updated
set _goals {}

# The option goals
set _optiongoals {}

# The targets (left-hand-side) of rules
array set _target {}

# The dependencies (right-hand-side) of rules
array set _dependency {}

# The corresponding commands
array set _command {}

# The make-variables
array set _vars {}

# A unique counter for rule ids
set _unique 0

# The array of up-to-date targets
array set _uptodate {}

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
	package require tclmake

	# Set variables and call the _tclmake procedure
	set _vars(MAKE) "tclmake"
	set _vars(MAKEDIR) [pwd]
	set _vars(MAKEVARS) ""
	set _vars(MFLAGS) ""
	eval _tclmake $args
    }
    set script [subst -nocommands $script]
    $interp eval $script
}

#######################################################################
#### _tclmake
# The real main tclmake procedure. This procedure processes options,
# initiates the file parsing and goal resolution, and
# performs the recursive tclmake.
# 
proc _tclmake {args} {
    global _flags _goals _optiongoals _vars _makedata
    global _target _depend _unrecognized
    global env

    # Print the current directory
    puts [pwd]

    # Process command-line arguments
    if [eval _processCommandLine $args] {
	return 1
    }

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
    if $_flags(debug) {
	puts "Reading file \"$file\""
    }

    # Parse it
    _parseFile $file

    # Check that all command-line options have now been
    # defined
    if { $_unrecognized != "" } {
	puts "Unrecognized command-line options: $_unrecognized. Continuing..."
    }

    # Get a default goal if needed
    if { $_goals == {} && [array size _target] != 0 } {
	# Get the default goals. Only works for simple rules.
	set _goals $_target(1)
    }

    # Evaluate the goals. Options get processed after regular goals
    if $_flags(debug) {
	puts "Processing rules..."
    }
    foreach goal [concat $_goals $_optiongoals] {
	_updateTarget $goal
    }
}

#######################################################################
#### _processCommandLine
# Extract command options into the _flags array. If an option
# is undrcognized, place it into the _unrecognized list
# for later recognition.
# 
proc _processCommandLine {args} {
    global _flags _goals _optiongoals _vars _unrecognized

    set optiongoals {}

    # Process command-line args
    while { $args != "" } {
	set option [lindex $args 0]
	set args [lreplace $args 0 0]

	if ![string match {-*} $option] {
	    # Got a goal
	    lappend _goals $option
	    continue

	} elseif [regexp {^([^ =]*)=(.*)$} $option _ name value] {
	    # Got a variable value
	    set _vars($name) $value
	    lappend _vars(MAKEVARS) $option
	    continue

	} else {
	    switch -exact -- $option {
		"-d" -
		"--debug" {
		    set _flags(debug) 1
		}
		"-f" -
		"--file" {
		    set _flags(file) [lindex $args 0]
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
		default {
		    # Unknown option. What we do here is add it
		    # to the list of unrecognized options, so that
		    # we know if it doesn't get defined. We also add
		    # it to the list of option goals, so that it will
		    # get run.
		    lappend _unrecognized $option
		    lappend _optiongoals $option
		}
	    }
	    lappend _vars(MFLAGS) $option
	}
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
    puts "Notmake, version 0.1. Usage:"
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
