# Embedding Python Into Bash

This project demonstrates how to embed the Python interpreter into a Bash shell.
This allows you to call Python methods natively from Bash, without invoking a
Python subprocess.

The core logic is in `python.sh`. This has the logic for initializing the
interpreter, compiling code objects, and marshaling function parameters. You can
source this file from another script.

By convention all parameters to methods are converted to strings and function
return values are also treated as strings. This means that in your Python
methods you will have to cast from a string type if you expect arguments of
another type (say, integers).

An example program is listed in `primes.sh`, which implements the Rabin-Miller
primality test in Python and exposes it to Bash.
