# perl-pp-autolink

pp is a tool that packs perl scripts and their dependencies into a stand alone executable.  https://metacpan.org/pod/pp

However, it currently does not find external DLLs. These can be added to the pp call using the --link option,
but known which DLLs to list is a source of general angst.  This tool automates that process.

The pp_autolink.pl script finds dependent DLLs and passes them to a pp call.

It has been tested for Windows machines only so far.  It is untested on linux, and is unlikely to work on macs.  

The argument list is the same as for pp.  

```perl
perl pp_autolink.pl -o some.exe some_script.pl
```

Note that currently only one script is supported, and it must be the last entry in the command.  


### Acknowledgements ###

The logic has been adapted from the pp_simple.pl script at https://www.perlmonks.org/?node_id=1148802
