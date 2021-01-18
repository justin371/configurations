#!/usr/bin/env bash

for i in *yml; do
    if [[ ! -s $i.dd || $i -nt $i.dd ]]; then
      echo Rebuilding $i
      perl -MYAML=LoadFile -MData::Dumper -e "print Dumper(LoadFile('$i'))">$i.dd
    fi
done
