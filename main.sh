#!/bin/bash

# where ctypes.sh is installed; you will likely have to change this
LD_LIBRARY_PATH=$HOME/local/lib
. ~/code/ctypes.sh/ctypes.sh

# this is a 64-bit system
declare -i wordsize=8
declare -i PY_FILE_INPUT=257
declare -r ZERO=int:0

script=$(cat<<EOF
def add(*args):
    return sum(int(arg) for arg in args)
EOF
)

function ensure_not_null {
    if [ "$1" = $NULL ]; then
        echo "null result"
        exit 1
    fi
}

trap "rm -f $sofile python.c" EXIT

declare -a words
words=(string:1 string:2 string:3)
numwords=${#words[@]}

# allocate space for our packed words
dlcall -n buffer -r pointer malloc $((numwords * wordsize))
pack $buffer words

# load the code
dlopen libpython2.7.so

# initialize the python interpreter
dlcall Py_Initialize

dlcall -n pytuple -r pointer PyTuple_New long:$numwords

i=0
for word in "${words[@]}"; do
    dlcall -n s -r pointer PyString_FromString $word
    ensure_not_null $s
    dlcall -n r -r int PyTuple_SetItem $pytuple long:$i $s
    if [ $r != $ZERO ]; then
        echo "failed to PyTuple_SetItem"
        exit 1
    fi
    i=$((i + 1))
done

dlcall -n pycompiled -r pointer Py_CompileString string:"$script" "" $PY_FILE_INPUT
ensure_not_null $pycompiled

dlcall -n pymodule -r pointer PyImport_ExecCodeModule string:add $pycompiled
ensure_not_null $module

dlcall -n pyfunc -r pointer PyObject_GetAttrString $pymodule string:add
ensure_not_null $pyfunc

# call the function
dlcall -n out -r pointer PyObject_CallObject $pyfunc $pytuple

# unmarshal the return value
dlcall -n res -r long PyInt_AsLong $out
printf "return value is %d\n" $(echo $res | egrep -o '[0-9]+')
