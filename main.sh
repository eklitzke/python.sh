#!/bin/bash

# where ctypes.sh is installed; you will likely have to change this
LD_LIBRARY_PATH=$HOME/local/lib
. ~/code/ctypes.sh/ctypes.sh

# this is a 64-bit system
declare -i wordsize=8
declare -i PY_FILE_INPUT=257
declare -r ZERO=int:0

function ensure_not_null {
    if [ "$1" = $NULL ]; then
        echo "null result"
        exit 1
    fi
}

declare -i is_inited=0

# lazily initialize the interpreter
function init_python {
    if [ $is_inited -eq 0 ]; then
        # initialize the python interpreter
        dlopen libpython2.7.so
        dlcall Py_Initialize
        is_inited=1
    fi
}

function load_module {
    if [ $# -ne 1 ]; then
        echo "usage: load_module <script>"
        exit 1
    fi

    # compile the script to a code object
    dlcall -n pycompiled -r pointer Py_CompileString string:"$1" "" $PY_FILE_INPUT
    ensure_not_null $pycompiled

    # compile the code object to a module
    dlcall -n pymodule -r pointer PyImport_ExecCodeModule string:"magic" $pycompiled
    ensure_not_null $pymodule
}

function get_attribute {
    if [ $# -ne 1 ]; then
        echo "usage: get_attribute <attribute_name>"
        exit 1
    fi

    # get the function from the module
    dlcall -n pyfunc -r pointer PyObject_GetAttrString $pymodule string:"$1"
    ensure_not_null $pyfunc
}

code=$(cat<<EOF
import random
import sys

def is_probable_prime(n, k = 7):
   """use Rabin-Miller algorithm to return True (n is probably prime)
      or False (n is definitely composite)"""
   if n < 6:  # assuming n >= 0 in all cases... shortcut small cases here
      return [False, False, True, True, False, True][n]
   elif n & 1 == 0:  # should be faster than n % 2
      return False
   else:
      s, d = 0, n - 1
      while d & 1 == 0:
         s, d = s + 1, d >> 1
      # Use random.randint(2, n-2) for very large numbers
      for a in random.sample(xrange(2, min(n - 2, sys.maxint)), min(n - 4, k)):
         x = pow(a, d, n)
         if x != 1 and x + 1 != n:
            for r in xrange(1, s):
               x = pow(x, 2, n)
               if x == 1:
                  return False  # composite for sure
               elif x == n - 1:
                  a = 0  # so we know loop didn't continue to end
                  break  # could be strong liar, try another a
            if a:
               return False  # composite if we reached end of this loop
      return True  # probably prime if reached end of outer loop
EOF
)

init_python
load_module "$code"
get_attribute is_probable_prime

for x in {2..100}; do
    dlcall -n pytuple -r pointer PyTuple_New long:1
    ensure_not_null $pytuple

    dlcall -n num -r pointer PyInt_FromLong long:$x
    ensure_not_null $num

    dlcall -n r -r int PyTuple_SetItem $pytuple long:0 $num
    if [ "$r" != $ZERO ]; then
        echo "failed to PyTuple_SetItem"
        exit 1
    fi

    # call the add function
    dlcall -n out -r pointer PyObject_CallObject $pyfunc $pytuple
    ensure_not_null $out

    # unmarshal the return value
    dlcall -n res -r long PyInt_AsLong $out
    printf "is_probable_prime: %d -> %d\n" $x $(echo $res | egrep -o '[0-9]+')

    # don't leak memory
    dlcall Py_DecRef $out
    dlcall Py_DecRef $pytuple
done
