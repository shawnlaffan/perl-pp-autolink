# perl-pp-autolink
Find dependent DLLs and add them to a pp call


A major bane when building standalone perl executables using pp from PAR::Packer is knowing which dependent DLLs to add to the call using the --link option.  This tool automates that process.

The pp_autolink.pl script finds dependent DLLs and passes them to a pp call.

It has been tested for Windows machines only so far.  It is untested on linux, and is unlikely to work on macs.  

The argument list is the same as for pp.  https://metacpan.org/pod/pp

```perl
perl pp_autolink.pl -o some.exe some_script.pl
```

Note that currently only one script is supported, and it must be the last entry in the command.  
