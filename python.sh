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
