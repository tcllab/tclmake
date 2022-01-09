# update.tcl: procedures for updating targets
#
# @Author: John Reekie
#
# @Version: @(#)update.tcl	1.4 05/19/98
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
#### _leeryGlob
# Perform a glob -nocomplain on a list of patterns, except
# that, if a pattern does not return any files, figure
# out if this is because it is a pattern and there are
# no files, or if it is because it's not a pattern.
# This is needed to get the expected results in the presence of
# phony targets.
#
proc _leeryGlob {args} {
    set result {}
    foreach patt $args {
	set files [glob -nocomplain -- $patt]
	if { $files != "" } {
	    set result [concat $result $files]
	} else {
	    # If it's not a pattern, add it anyway
	    if ![regexp {\?|\*|\[.*\]|\{.*\}} $patt] {
		lappend result $patt
	    }
	}
    }
    return $result
}

#######################################################################
#### _updateTarget
# Update a target. This procedure first checks if the target has already
# been updated, in which case it returns 1. Otherwise, it
# searches for rules containing this target, and if it finds any,
# it determines if any dependency is out-of-date. If any are,
# then it updates each of them, and then executes the command
# for that rule, marks the target as updated. If the target
# is updated anywhere, return 1, otherwise return 0.
#
proc _updateTarget {target {caller {}}} {
    global _target _depend _updated _command _terminal _flags

    if $_flags(debug) {
	puts "Updating $target"
    }

    # Check if it has already been updated
    if [info exists _updated($target)] {
	return 1
    }
    set updated 0

    # Find the rules in which it appears on the left
    foreach {id lhs} [array get _target] {
	set found 0

	if $_flags(debug) {
	    # Too verbose: _printrule $id
	}

	set lhs [eval _leeryGlob $lhs]
	if { [lsearch -exact $lhs $target] >= 0 } {
	    set found 1
	} elseif { $lhs == "" } {
	    set found 1
	}
	if !$found {
	    continue
	}

	# Get the dependencies, according to rule type
	set rhs [string trim $_depend($id)]
	if [regexp "^(\[^:\]*) :+ (\[^:\]*)\$" $rhs _ tpatt dpatt] {
	    regsub -all {%} $tpatt {*} plist
	    set dependencies ""
	    foreach p $plist t $tpatt {
		if [string match $p $target] {
		    # OK, it's a match. Convert to regexp and get the stem
		    regsub -all {\.} $t {\\.} t
		    regsub -all {%} $t (.*) t
		    regexp "^$t\$" $target _ stem
		    # Now get the dependencies
		    regsub -all {%} $dpatt $stem dependencies
		}
	    }
	    # If there is a set of targets, and the rule is a terminal
	    # rule and none of the dependencies exist, then
	    # check the _right-hand-side_ patterns against existing
	    # files to generate additional goals. This is a special
	    # case handled by tclmake.
	    if { $lhs != "" && $_terminal($id) } {
		set reverse 1
		foreach d $dependencies {
		    if [file exists $d] {
			set reverse 0
			break
		    }
		}
	    } else {
		set reverse 0
	    }
	    # Do the reverse pattern-matching
	    if $reverse {
		regsub -all {%} $dpatt {*} plist
		foreach p $plist d $dpatt {
		    set files [glob -nocomplain -- $p]
		    if { $files != "" } {
			# We got at least one file. For each,
			# generate the goal from the lhs pattern
			regsub -all {\.} $d {\\.} d
			regsub -all {%} $d (.*) d
			foreach f $files {
			     regexp "^$d\$" $f _ stem
			    # Now get the dependencies and update
			    regsub -all {%} $tpatt $stem goals
			    foreach g $goals {
				set updated [expr {[_update $g $target $f \
					$_terminal($id) $_command($id)] \
					|| $updated }]
			    }
			}
		    }
		}
		# Now we are done with this rule
		continue
	    }
	} else {
	    # Otherwise, it must (I think?) be a simple rule
	    set dependencies [eval _leeryGlob $rhs]
	}
	set updated [expr { [_update $target $caller $dependencies \
		$_terminal($id) $_command($id)] || $updated }]

    }

    if { !$updated && $_flags(debug) } {
	puts "Nothing to do for $target"
    }
    # Return 1 if the target was updated in any rule
    return $updated
}



#######################################################################
#### _update
# Update a target if the dependencies say so. Return 1 if it was
# updated, otherwise 0.
#
proc _update {target caller dependencies terminal cmd} {
    global _updated _flags _goals

    # If the caller is empty, then this must be a top-level call,
    # so use the goals
    if { $caller == "" } {
	set caller $_goals
    }

    # Process each dependency and figure out if the target
    # is out of date. If there are no dependencies, this target
    # is out of date anyway -- it's probably a phony target. If
    # the target does not exist (as a file), then it is out
    # of date. If the file exists and is older than any
    # dependency, the target is out of date. In any of
    # these cases, each dependency is updated if necessary,
    # and, if any is updated, then this target is out of date.
    #
    set outofdate 0
    if { ![file exists $target] || $dependencies == "" } {
	set outofdate 1
    }
    if $terminal {
	foreach d $dependencies {
	    if ![file exists $d] {
		set outofdate 0
	    }
	}
    }
    
    # Get modification date just once
    if [file exists $target] {
	set mtime [file mtime $target]
    } else {
	set mtime {}
    }
    set dollarquery {}
    foreach d $dependencies {
	if { $mtime != "" } {
	    # Check file dates
	    if { [file exists $d] } {
		if { [file mtime $d] > $mtime } {
		    if !$terminal {
			_updateTarget $d $target
		    }
		    lappend dollarquery $d
		    set outofdate 1

		} elseif !$terminal {
		    # Update only if dependency is updated
		    if [_updateTarget $d $target] {
			lappend dollarquery $d
			set outofdate 1
		    }
		}
	    } elseif !$terminal {
		# Attempt to update intermediate targets
		# only if this is not a terminal rule
		if [_updateTarget $d $target] {
		    lappend dollarquery $d
		    set outofdate 1
		}
	    }
	} elseif !$terminal {
	    # Attempt to update intermediate targets
	    # only if this is not a terminal rule
	    if [_updateTarget $d $target] {
		lappend dollarquery $d
		set outofdate 1
	    }
	} 
    }

    # If this target needs updating, update it
    if $outofdate {
	set cmd [_substVars $cmd]                 ;# substitute variables
	regsub -all {\$\!} $cmd $caller cmd       ;# the caller
	regsub -all {\$\@} $cmd $target cmd       ;# the target    
	regsub -all {\$\<} $cmd \
		[lindex $dependencies 0] cmd      ;# the first dependency 
	regsub -all {\$\?} $cmd $dollarquery cmd  ;# updated dependencies
	regsub -all {\$\^} $cmd $dependencies cmd ;# all dependencies
	if [info exists stem] {
	    regsub -all {\$\*} $cmd $stem cmd     ;# matched stem
	}

	if $_flags(debug) {
	    puts "Executing command to update $target:"
	}
	# Scan for and remove any leading "@" signs. If there is
	# no leading @-sign, print the command.
	# append cmd \n
	while { [regexp "^(\[^\n\]*)\n(.*)\$" $cmd _ line cmd] } {
	    # Read a line and check for an @
	    set print 1
	    if [regexp "^\[ \t\]*@" $line] {
		regsub "^\[ \t\]*@" $line {} line
		set print 0
	    }
	    # Get a complete command
	    set execute $line
	    while { ![info complete $execute] && $cmd != "" } {
		regexp "^(\[^\n\]*)\n(.*)\$" $cmd _ line cmd
		append execute \n$line
	    }
	    # Print it
	    if $print {
		puts $execute
	    }
	    # Evaluate it
	    set errorcode [catch {uplevel #0 $execute} msg]
	    if $errorcode {
		# There was a return error code
		if { $errorcode == 3 } {
		    # The error was from a break, so stop processing
		    # this command
		    break
		} else {
		    _error $msg
		}
	    }
	}
    }
    # Mark this target as updated, as long as it isn't an option
    if ![string match {-*} $target] {
	set _updated($target) $outofdate
    }
    return $outofdate
}
