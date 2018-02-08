# Linker Ideas


## How to use this linker

This linker is meant to be compiled into a command-line executable, or a library.  Performance will be the highest priority.  Given this requirement, it uses a "policy-based" api that allows applications to generate custom linkers that are optimized for their use cases.