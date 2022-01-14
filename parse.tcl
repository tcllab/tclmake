# parse.tcl: procedures for parsing tclmake files
#
# Author: John Reekie
#
# $Id$
#
# Copyright (c) 1997-1998 The Regents of the University of California.
# Changes Copyright (c) 2022 Stephen E. Huntley <stephen.huntley@alum.mit.edu>
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
#### _printrule
# Helper proc to print sensible debug messages about parsed rules
#
proc _printrule {id} {
    global _flags _target _depend _terminal

    if $_flags(debug) {
	set colon :
	if {$_terminal($id)} {set colon ::}

	if { $_target($id) == "" } {
	    puts "Rule $id = $_depend($id)"
	} else {
	    puts "Rule $id = $_target($id) $colon $_depend($id)"
	}
    }
}

#######################################################################
# Hard code definition of '--packages' and '--recursive' rules so they are
# always available to include in dependency lists and can be specified on
# command line
set id [incr _unique]
set _target($id) "-p --packages"
set _depend($id) ""
set _terminal($id) 0
set _target_type($id) explicit
set _command($id) {        @foreach dir [glob -nocomplain */pkgIndex.tcl] {
                set dir [file dirname $dir]
                if { [file type $dir] == "directory" && [file executable $dir] } {
                        cd $dir
                        $(MAKE) $(MFLAGS) $(MAKEVARS) $!
                }
        }
    
}
_printrule $id

set id [incr _unique]
set _target($id) "-r --recursive"
set _depend($id) ""
set _terminal($id) 0
set _target_type($id) explicit
set _command($id) {        @foreach dir [glob -nocomplain -type {d x} *] {
                cd $dir
                $(MAKE) $(MFLAGS) $(MAKEVARS) $!
    }

}
_printrule $id

#######################################################################
#### _parseFile
# Extract data from a makefile. This reads the file, looking
# for directives like include and use, variable definitions,
# rules, and so on.
#
proc _parseFile {filename} {
    global _vars _target _depend _command 
    global _unique _flags _terminal _unrecognized
    global _target_type

    # Open the file
    set fd [open $filename]

    # Patterns.
    # word is anything expect space or colon or percent sign
    set word "\[^ \t:%\]+"
    # Space is any white-space
    set space "\[ \t]*"
    # Space is some white-space
    set spaces "\[ \t]+"
    # stem is anything except space, colon, or period 
    set stem "\[^ \t:.\]+"
    # pattern is anything with a prefix, suffix, and a percent in the middle
    set ppatt "$word%$word"

    set break 0
    # Read a line at a time
    while { ![eof $fd] || $break } {
        
	# Fix bug where line after rule definition is ignored
	if {$break} {
       	set break 0
	} else {
       	set line [gets $fd]
	}
	
	set foundrule 0

	# If the line ends with a backslash, continue it
	while { ![eof $fd] && [regexp {\\$} $line] } {
	    set line [string trimright [string trimright $line "\\"]]
	    append line " " [string trimleft [gets $fd]]
	}

	if [regexp "^$space#" $line] {
	    # Comment

	} elseif [regexp "^$space$" $line] {
	    # Blank

	} elseif [regexp "^${space}include${spaces}(.*)$" $line _ file] {
	    # Include another file
	    _parseFile [string trim [_substVars $file]]

	} elseif [regexp "^${space}use${spaces}(.*)$" $line _ file] {
	    # Use a regular makefile for variables
	    _useMakefile [_substVars $file]

	} elseif [regexp "^${space}source${spaces}(.*)$" $line _ file] {
	    # Source another file
	    source [string trimleft [_substVars $file]]

	} elseif [regexp "^${space}proc${spaces}(.*)$" $line] {
	    # Define a Tcl proc
	    set tclproc $line\n
	    while { ![eof $fd] && ![info complete $tclproc] } {
		append tclproc [gets $fd]\n
	    }

	    $::makefile_interp eval $tclproc

	} elseif [regexp "^${space}(.*)${space}=${space}(.*)$" $line \
		_ name value] {
	    # Variable definition. Set only if doesn't already exist,
	    # so as not to overwrite command-line vars.
	    set name [string trim $name]
	    if ![info exists _vars($name)] {
		set _vars($name) $value
		if $_flags(debug) {
		    puts "$name = $value"
		}
	    }
	} elseif [regexp "^\\.($stem)\\.($stem)${space}:$space$" $line\
		_ dep tgt] {
	    # Suffix rule -- convert and save as pattern rule
	    set id [incr _unique]
	    set _target($id) ""
	    #set _depend($id) "%.$tgt %.$dep"
	    set _depend($id) "%.[string trim $tgt] : %.[_substVars [string trim $dep]]"
	    set _terminal($id) 0
	    set foundrule 1
	    set _target_type($id) implicit
	    if $_flags(debug) {
	        puts "\nSuffix rule:"
	    }

	} elseif [regexp "^(-\[^:\]*)${space}:$space\$" $line _ tgt] {
	    # An option-rule. Remember it and remove it from the
	    # unrecognized list
	    set id [incr _unique]
	    set _target($id) "$tgt"
	    set _depend($id) ""
	    set _terminal($id) 0
	    foreach t $tgt {
		set i [lsearch -exact $_unrecognized $t]
		if { $i >=0 } {
		    set _unrecognized [lreplace $_unrecognized $i $i]
		}
	    }
	    set foundrule 1
	    set _target_type($id) explicit
	    if $_flags(debug) {
	        puts "\nOption rule:"
	    }

	} elseif { [regexp {%} $line] \
		&& [regexp "^(\[^:\]*)(:+)(\[^:\]*)$" $line \
		_ tgt colons dep] } {
	    # Pattern rule with implicit targets
	    set id [incr _unique]
	    set _target($id) ""
	    set _depend($id) "[string trim $tgt] $colons [_substVars [string trim $dep]]"
	    set _terminal($id) [expr {$colons == "::"}]
	    set foundrule 1
	    set _target_type($id) implicit
	    if $_flags(debug) {
		puts "\nPattern rule with implicit targets:"
	    }

	} elseif { (1 || [regexp {%} $line]) \
		&& [regexp "^(\[^:\]*):(\[^:\]+)(:+)(\[^:\]*)$" $line _ \
		lhs tgt colons dep] } {
	    # Pattern rule with explicit targets
	    set id [incr _unique]
	    set _target($id) [_substVars $lhs]
	    set _depend($id) "[_substVars [string trim $tgt]] $colons [_substVars [string trim $dep]]"
	    set _terminal($id) [expr {$colons == "::"}]
	    set foundrule 1
	    set _target_type($id) explicit
	    if $_flags(debug) {
		puts "\nPattern rule with explicit targets:"
	    }

	} elseif { ![regexp {%} $line] \
		&& [regexp "^(\[^:\]+)${space}(:+)(\[^:\]*)$" $line _ \
		tgt colons dep] } {
	    # Simple rule

	    set tgt [_substVars [string trim $tgt]]
	    set dep [string trim [_substVars $dep]]
	    set terminal [expr {$colons == "::"}]

	    set id [incr _unique]
	    set _target($id) $tgt
	    append _depend($id) " $dep"
	    set _depend($id) [string trim $_depend($id)]
	    
	    set _terminal($id)  [expr {$colons == "::"}]
	    set foundrule 1
	    set _target_type($id) explicit
	    if $_flags(debug) {
		puts "\nSimple rule:"
	    }

	} else {
	    puts "Unrecognized rule: $line"
	}
	# If we found a rule, read the command following it
	if $foundrule {
	    _printrule $id
	    set command {}
	    while { ![eof $fd] } {
		set line [gets $fd]

		# A command starts with space, and then has non-blank
		if [regexp "^\[ \t\]+\[^ \t\]" $line] {
		    append command $line\n
		} else {
		    set break 1
		    break
		}
	    }
	    
	    set _command($id) $command
	}
    }
    close $fd
}

#######################################################################
#### _useMakefile
# Load makefiles used for variable definitions.
# 
proc _useMakefile {filename} {
    global _makefiledata _flags

    if $_flags(debug) {
	puts "Using makefile \"$filename\""
    }

    # For regular makefiles, try not to barf if the file doesn't exist
    if ![file exists $filename] {
	if !$_flags(silent) {
	    puts "Unable to read makefile: \"$filename\""
	}
	return
    } else {
	_catcherror {
	    set fd [open $filename]
	    append _makefiledata [read $fd]
	    close $fd
	}
    }

    while { [regexp "\n\[ \t\]*include\[ \t\]*(\[^\n\]*)\n" \
	    $_makefiledata q file] } {
	# Substitute other files
	set file [string trim [_substVars $file]]
	if $_flags(debug) {
	    puts "Using makefile \"$file\""
	}
	# For regular makefiles, try not to barf if the file doesn't exist
	set data ""
	if ![file exists $file] {
	    if !$_flags(silent) {
		puts "Unable to read makefile: \"$file\""
	    }
	} else {
	    _catcherror {
		set fd [open $file]
		set data [read $fd]
		close $fd
	    }
	}
	# Backquote ampersands to avoid unwanted substitutions
	regsub -all {&} $data {___tclmake_ampersand___} data
	regsub "\n\[ \t\]*include\[ \t\]*\[^\n\]*\n" \
		$_makefiledata \n$data _makefiledata
    }
    # Restore ampersands
    regsub -all {___tclmake_ampersand___} $_makefiledata {\&} _makefiledata

    # Join backslash lines
    regsub -all "\[ \t\]*\\\\\n\[ \t\]*" $_makefiledata " " _makefiledata
}

#######################################################################
#### _substVars
# Substitute make-file variables into a string.
# 
proc _substVars {string} {
    global _vars
    set varpatt "\\\$\\((\[^\)\]*)\\)"
    while { [regexp $varpatt $string _ varname] } {
	_catcherror {
	    set value [_getVar $varname]
	}
	regsub -all {&} $value {___tclmake_ampersand___} value
	regsub $varpatt $string $value string
    }
    regsub -all {___tclmake_ampersand___} $string {\&} string
    return $string
}

#######################################################################
#### _getVar
# Get the value of a variable. This procedure calls itself
# recursively to find the final value. The first place it looks
# for a variable value is in the variable definitions read
# from the tclmakefiles; if it doesn't find it, it scans the
# makefile read with the "uses" directive to see if there is
# a value there. If it still doesn't find it, look in the
# environment. Finally, throw an error.
# 
proc _getVar {varname} {
    global _vars _usevars _makefiledata _flags
    global env

    # Get its current value
    if [info exists _vars($varname)] {
	set v $_vars($varname)
    } else {
	# Didn't find one -- look in the data read from a
	# regular makefile to see if there is one
	set space "\[ \t]*"
	if [regexp "\n${space}$varname${space}=${space}(\[^\n#\]*)" \
		$_makefiledata _ v] {
	    set _vars($varname) $v
	} else {
	    # Nope -- try the environment
	    if [info exists env($varname)] {
		#set _vars($varname) $env($varname)
		set v $env($varname)
	    } else {
		#error "Unknown variable: $varname"
		set v {}
		if $_flags(debug) {
		    puts "No value found for variable $varname. Setting to empty string."
		}
	    }
	}
    }

    # If it contains variable references, resolve them
    set varpatt "\\\$\\((\[^\)\]*)\\)"
    while { [regexp $varpatt $v _ varname] } {
	set value [_getVar $varname]
	regsub -all {&} $value {___tclmake_ampersand___} value
	regsub $varpatt $v $value v
    }
    regsub -all {___tclmake_ampersand___} $v {\&} v
    return $v
}
