#! /bin/sh

flist=`find . -type f -and -not -name '*.exe' \
                      -and -not -name '*.obj' \
                      -and -not -name '*.sym' \
                      -and -not -name '*.swp' \
                      -and -not -name '*.dsk' \
                      -and -not -name '*.bak' \
                      -and -not -name '*.map' \
                      -and -not -name '*.lst' \
                      -and -not -name '*.log' \
                      -and -not -name '*.ide' \
                      -and -not -name '*.dsw' \
                      -and -not -name '*.td' \
                      -and -not -name '*.tdw' \
                      -and -not -name '*.~de' \
                      -and -not -name '*.tr' \
                      -and -not -name '*.csm' \
                      -and -not -name 'arh/*.*' \
                      -and -not -name '*.bkp' | sed -e 's,^\./,,g'`

tar cyf tdrv-`date +%Y%m%d`.tar.bz2 $flist


