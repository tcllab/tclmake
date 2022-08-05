# Limitations

Option-dependencies will not be processed in terminal rules. For example, the rule

    sources: % :: SCCS/s.% --recursive
    	exec sccs get $@

will not be recursive, since the fact that it is a terminal rule prevents "--recursive" from being updated.  (Specifying the option on the command line still works.) 

tclmake is not supposed to be a replacement for make. With that in mind, here are some features of other make implementations that tclmake does not support.

- Non-recursive variables.
- Appending to variables.
- Filtering functions.
- The VMAKE variable. 