#!/bin/bash

TARGET="$1"

if [[ $# -eq 0 ]] ; then
    echo 'target required'
    exit 0
fi

cd "${TARGET}"

sed -i -e 's#source = "../oke"#source = "./oke"#g' provider.tf
mkdir oke
cp ../oke/*.tf oke/

zip -q "../${TARGET}-stack.zip" schema.yaml *.tf oke/*.tf

rm -rf oke/
sed -i -e 's#source = "./oke"#source = "../oke"#g' provider.tf

cd ..
