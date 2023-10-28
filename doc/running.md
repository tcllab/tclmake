# Invoking tclmake

In the project sub-directory **bin** is an executable shell script file 
**tclmake** that will run the tclmake program.  You can add the **bin** 
sub-directory to your **PATH** environment variable, or create a symbolic link 
to the **tclmake** in a directory already in your **PATH**.

Then, from a command shell, change to the directory in which you want tclmake 
to run, and type

    tclmake

tclmake will run in that directory and attempt to make the targets of the first 
rule in the default tclmakefile. The full calling syntax of tclmake is:

    tclmake ?<options>? ?<variables>? ?<goal ...>? 

Each goal is the name of a target that tclmake will attempt to update. If none 
is supplied, tclmake will use the first target in the tclmakefile. The 
variables are variable overrides, which have the syntax:

    VARNAME=varvalue 

The given variable will have its value set to the given value, and the value in 
the tclmakefile will be ignored. The options are keywords beginning with a 
dash. 

tclmake accepts the following options:
    
    -d 
    --debug 
          Print debugging information. 
    -f <filename> 
    --file <filename> 
          Use specified file as the tclmakefile. 
    -h 
    --help 
          Print out this list of options. 
    -p 
    --packages 
          Recursively process directories that contain a pkgIndex.tcl file.
    -r 
    --recursive 
          After processing the current directory, tclmake will be re-executed in
          sub-directories using the same command-line settings.  The recursion
          will continue through the entire hierarchy of sub-directories.
    -s 
    --silent 
    --quiet 
          Print no information at all to stdout or stderr. 
    -t 
    --terminator
          Treat rules for all given goals as terminator rules; i.e., do not
          attempt to follow chain of dependencies, assume all dependencies for
          specified goals are up to date. Unlike a standard terminal rule, 
          missing dependency files are ignored and each rule command is 
          executed regardless.
    -u 
    --update 
          Ignore timestamps and update targets even if they're not out of date. 

Alternatively, tclmake can be run as a procedure in a Tcl interpreter by 
loading the tclmake package.  Once the package is loaded the procedure 
`tclmake` can be executed with the same calling syntax as the command-line 
script.
