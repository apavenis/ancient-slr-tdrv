.autodepend

.asm.obj:
        c:\borlandc\bin\tasm.exe /m2 /ml /zi /t $<

asmlib.lib:     allocumb.obj    \
                args.obj        \
                chartbl.obj     \
                choutp.obj      \
                dosmin.obj      \
                findword.obj    \
                ini.obj         \
                intvect.obj     \
                is286.obj       \
                is386.obj       \
                ltoax.obj       \
                getenv.obj      \
                meminfo.obj     \
                openfp.obj      \
                prfarptr.obj    \
                prhexw.obj      \
                printf.obj      \
                print_r.obj     \
                prnum.obj       \
                rdtime.obj      \
                strcpy.obj      \
                stroutp.obj     \
                textfile.obj    \
                truename.obj    \
                whichcpu.obj
   del  asmlib.lib
   tlib /C /E asmlib.lib @&&|
        +allocumb.obj   &
        +args.obj       &
        +chartbl.obj    &
        +choutp.obj     &
        +dosmin.obj     &
        +findword.obj   &
        +ini.obj        &
        +intvect.obj    &
        +is286.obj      &
        +is386.obj      &
        +ltoax.obj      &
        +getenv.obj     &
        +meminfo.obj    &
        +openfp.obj     &
        +prfarptr.obj   &
        +prhexw.obj     &
        +printf.obj     &
        +print_r.obj    &
        +prnum.obj      &
        +rdtime.obj     &
        +strcpy.obj     &
        +stroutp.obj    &
        +textfile.obj   &
        +whichcpu.obj   &
        +truename.obj   &
        , asmlib.lst
|
