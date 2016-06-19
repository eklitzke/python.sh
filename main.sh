#!/bin/bash

# where ctypes.sh is installed; you will likely have to change this
LD_LIBRARY_PATH=$HOME/local/lib
. ~/code/ctypes.sh/ctypes.sh

# this is a 64-bit system
declare -i wordsize=8
declare -r ZERO=int:0

script=$(cat<<EOF
def add(*args):
    return sum(int(arg) for arg in args)
EOF
)

cat<<EOF >python.c
#include <assert.h>

#include <Python.h>

// XXX: leaks references
PyObject *CreateFunction(const char *funcname, const char *code) {
  // compile a code object
  PyObject *compiled = Py_CompileString(code, "", Py_file_input);
  assert(compiled != NULL);

  // build a module w/ the code object
  PyObject *module = PyImport_ExecCodeModule((char *)funcname, compiled);
  assert(module != NULL);

  // get the function we created
  PyObject *method = PyObject_GetAttrString(module, (char *)funcname);
  assert(method != NULL);

  return method;
}
EOF

function build_python {
    sofile=$(mktemp /tmp/XXXXXX.so)
    cc $(pkg-config --cflags --libs python) -fPIC -shared python.c -o $sofile 2>/dev/null
    echo $sofile
}

sofile=$(build_python)

trap "rm -f $sofile python.c" EXIT

declare -a words
words=(string:1 string:2 string:3)
numwords=${#words[@]}

# allocate space for our packed words
dlcall -n buffer -r pointer malloc $((numwords * wordsize))
pack $buffer words

# load the code
dlopen $sofile

# initialize the python interpreter
dlcall Py_Initialize

dlcall -n pytuple -r pointer PyTuple_New long:$numwords

i=0
for word in "${words[@]}"; do
    dlcall -n s -r pointer PyString_FromString $word
    if [ $s = $NULL ]; then
        echo "failed to PyString_FromString"
        exit 1
    fi
    dlcall -n r -r int PyTuple_SetItem $pytuple long:$i $s
    if [ $r != $ZERO ]; then
        echo "failed to PyTuple_SetItem"
        exit 1
    fi
    i=$((i + 1))
done

# create a python function object for "add"
dlcall -n pyfunc -r pointer CreateFunction string:add string:"$script"

# call the function
dlcall -n out -r pointer PyObject_CallObject $pyfunc $pytuple

# unmarshal the return value
dlcall -n res -r long PyInt_AsLong $out
printf "return value is %d\n" $(echo $res | egrep -o '[0-9]+')
