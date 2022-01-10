** This is the original README for tclmake 1.0              **
** For the latest information on tclmake 2.0, see README.md **

README file for the tclmake package

tclmake is a simple make-like utility written entirely in
Tcl. It is written for use in situations in which you need
make-like support to install, use, or run Tcl on a platform
that may not have make installed.

tclmake uses a subset of make syntax for its rules, and
Tcl for its commands. Here is a sample of a "tclmakefile":

----
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
        @if { [glob -nocomplain *~ core #*# ,* dist] == "" } {
	    break
	}
	eval file delete -force [glob -nocomplain *~ core #*# ,* dist]

----

tclmake runs under the following binaries:
    Tcl8.0 or later
    Itcl2.2 or later

tclmake provides the following packages:
    tclmake 0.1

tclmake requires the following packages:
    (none)

The latest distributtion of tclmake is always at:

http://ptolemy.eecs.berkeley.edu/~johnr/code/tclmake/

John Reekie, 02/10/98
