# update.tcl: procedures for updating targets
#
# @Author: John Reekie
#
# @Version: @(#)update.tcl	1.4 05/19/98
#
# @Copyright (c) 1997-1998 The Regents of the University of California.
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
	set patt [string map {| :} $patt]
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
    global _target _depend _updated _command _terminal _flags _unique _target_type
    
    if {![info exists _updated($target)]} {set _updated($target) 0}
    if {$_updated($target) == 1} {return 1}
    
    if $_flags(debug) {
	puts "Updating $target"
    }
    set updated 0
    set found 0
    set dependencies {}
    set command {}
    set target_cmd_type {}

    # Examine all defined rules from last to first, gather all dependencies
    # associated with target, grab last-defined command associated with target,
    # decide if evaluation is terminal or not based on last-defined rule
    for {set id $_unique} {$id > 0} {incr id -1} {
        
	# Check if simple rule
	set lhs $_target($id)
	set lhs [_leeryGlob {*}$lhs]
	if { [lsearch -exact $lhs $target] >= 0 } {
		# Grab id of last-defined rule associated with target
		if {!$found} {set found $id}
	} elseif { $lhs ne "" } {
	    	# It's a simple rule, but doesn't apply to target
		continue
	}

	# Get the dependencies, according to rule type
	set rhs [string trim $_depend($id)]
	if [regexp "^(\[^:\]*):+(\[^:\]*)\$" $rhs _ tpatt dpatt] {
	    
	    # Must be a pattern rule
	    regsub -all {%} $tpatt {*} plist

	    # Do pattern substution to see if target fits any rule pattern
	    foreach p $plist t $tpatt {
		if [string match $p $target] {
		    
		    # Grab id of last-defined rule associated with target
                 if {!$found} {set found $id}
                 
                 # If previously found rule is not the same terminal type,
                 # ignore
		    if {$_terminal($id) ne $_terminal($found)} {continue}
		    
		    # Ensure explicit target command overrides implicit
		    if {$target_cmd_type eq {implicit}
                  		   && $_target_type($id) eq {explicit}
                  		   && $_command($id) ne {}
                 } {set command {}}
		    
		    # Only overwrite existing command value if it is empty
		    if {[string trim $command] eq {}} {set command $_command($id)}
		    set target_cmd_type $_target_type($id)
		    
		    # OK, it's a match. Convert to regexp and get the stem
		    regsub -all {\.} $t {\\.} t
		    regsub -all {%} $t (.*) t
		    regexp "^$t\$" $target _ stem
		    
		    # Now get the dependencies
		    foreach dp $dpatt {
			regsub -all {%} $dp $stem dependency
			lappend dependencies $dependency
		    }
		    set dollar_stem $stem
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
		    # if pattern matches an actual existing file, this rule is not intended
		    # to apply, so skip
		    if [file exists $d] {
			set reverse 0
			break
		    }
		}
	    } else {
		set reverse 0
	    }
	    # Do the reverse pattern-matching
	    # If this is not the last-defined rule in the makefile that matches
	    # the target, skip; this is meant to be a standalone case since it
	    # generates its own targets and dependencies
	    if {$reverse && $found == $id} {
		regsub -all {%} $dpatt {*} plist
		foreach p $plist d $dpatt {
		    set files [glob -nocomplain -- $p]
		    if { $files != "" } {
			# We got at least one file. For each,
			# generate the goal from the lhs pattern
			regsub -all {\.} $d {\\.} d
			regsub -all {%} $d (.*) d
			foreach f $files {
			     set stem $tpatt
			     regexp "^$d\$" $f _ stem
			     set stem [string map {{ } {\ }} $stem]
			    # Now get the dependencies and update
			    regsub -all {%} $tpatt $stem goals
			    foreach g $goals {
				set updated [expr {[_update $g $target [list $f] \
					$_terminal($id) $_command($id)] \
					|| $updated }]
			    }
			}
		    }
		}
		# Now we are done with this rule
		if { !$updated && $_flags(debug) } {
               	puts "Nothing to do for $target"
             }
		return $updated
	    }
	} elseif {$lhs ne {}} {
	    # Otherwise, it must (I think?) be a simple rule
	    
	    # If previously found rule is not the same terminal type, ignore
	    if {$_terminal($id) ne $_terminal($found)} {continue}
	    
	    # Ensure explicit target command overrides implicit
	    if {$target_cmd_type eq {implicit}
        		    && $_target_type($id) eq {explicit}
        		    && $_command($id) ne {}
	    } {set command {}}
        		 
	    # Only overwrite existing command value if it is empty
	    if {[string trim $command] eq {}} {set command $_command($id)}
	    set target_cmd_type $_target_type($id)
	    
	    lappend dependencies {*}[_leeryGlob {*}$rhs]
	} 
    }

    # At least one rule has been found that applies to target
    if {$found} {
        # Make sure target is not listed among dependencies
        set dependencies [lsearch -inline -all -exact -not $dependencies $target]
        
        # Eliminate all redundantly-listed dependencies
        set dependencies [dict keys [dict create {*}[concat {*}[lmap v $dependencies {set v [list $v 0]}]]]]
        
        # Update target
        set updated [expr { [_update $target $caller $dependencies \
  		$_terminal($found) $command] || $updated }]
    } elseif {![file exists $target]} {
	puts "No rule to make target '$target', needed by '$caller'.  Stop."
	return -code 1 -errorcode missing_target
    }

    if { !$updated && $_flags(debug) } {
	puts "Nothing to do for $target"
    }
    # Return 1 if the target was updated in any rule
    set _updated($target) 1
    return $updated
}



#######################################################################
#### _update
# Update a target if the dependencies say so. Return 1 if it was
# updated, otherwise 0.
#
proc _update {target caller dependencies terminal cmd} {
    global _updated _flags _goals
    upvar dollar_stem stem
    if {![info exists stem]} {set stem {}}
    if {![info exists _updated($target)]} {set _updated($target) 0}

    if $_flags(terminal) {set terminal 1}
    if $_flags(update) {set terminal 0}

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
    if { ![file exists $target] } {
	set outofdate 1
    }
    if {$terminal && !$_flags(terminal)} {
	foreach d $dependencies {
	    if ![file exists $d] {
            puts "No rule to make target '$d', needed by '$target'.  Stop."
            return -code 1 -errorcode missing_target
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
    set _updated($target) 1
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
    
    # Check if forcing update via command-line argument
    if $_flags(update) {
    	
   	set _updated($target) 0
   	if $_flags(debug) {
      		if {!$outofdate} {
                puts "Update override via switch --update"
            }
   	}
   	set outofdate 1
 	
    }

    # Check special case where _updated may have been set by proc MAKE_UPDATE.
    # If so, override computed outofdate value
    lassign $_updated($target) MU upd
    if {$MU eq {MAKE_UPDATE}} {
        set outofdate [expr !$upd]
        set _updated($target) 1
    }
    
    # Mark this target as updated, as long as it isn't an option, or terminal
    set _updated($target) 1
    if {[string match {-*} $target] || $terminal} {
        set _updated($target) 0
    }
    
    # If this target needs updating, update it
    if $outofdate {
	# Define automatic variables
	set cmd [_substVars $cmd]                 ;# substitute variables
	regsub -all {\$\!} $cmd $caller cmd       ;# the caller
	regsub -all {\$\@} $cmd $target cmd       ;# the target    
	regsub -all {\$\<} $cmd \
		[lindex $dependencies 0] cmd      ;# the first dependency 
	regsub -all {\$\?} $cmd $dollarquery cmd  ;# updated dependencies
	regsub -all {\$\^} $cmd $dependencies cmd ;# all dependencies
	regsub -all {\$\*} $cmd $stem cmd     ;# matched stem

	if $_flags(debug) {
	    puts "Executing command to update $target:"
	}

	# Grab existing global vars from sub-interpreter, so any newly-created global
	# vars can be deleted afterward
	set makefile_globalVars [$::makefile_interp eval info globals]

	set workingDir [pwd]
	set report {set ec [catch {$execute} msg];return [list \$ec \$msg]} 

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
	    #set errorcode [catch {$::makefile_interp eval $execute} msg]
	    lassign [$::makefile_interp eval [subst -nocom $report]] errorcode msg
	    if $errorcode {
		# There was a return error code
		if { $errorcode > 1 } {
		    # The error was from a break, so stop processing
		    # this command
		    break
		} else {
		    _error $msg "$msg\n\twhile executing:\n$execute\n\tfor target: $target"
		}
	    }
	}

	cd $workingDir

	#Delete any newly-created global vars after running rule command
	lappend makefile_deleteGlobalsList
	foreach gv [$::makefile_interp eval info globals] {
	    if {$gv ni $makefile_globalVars} {
	        lappend makefile_deleteGlobalsList $gv
    	    }
	}
	$::makefile_interp eval unset -nocomplain $makefile_deleteGlobalsList

    }
    
    return $outofdate
}
