
Import-Module .\ILAsm.psm1

#
# A very simple method in IL
#
$sb = New-ILMethod {
    [outputtype([int])]
    param()

    Ldc.I4 6
    Ldc.I4 7
    Mul
    Ret
}

"Invoking our new method: $(& $sb)"

#
# A simple method in IL taking parameters
#
$sb = New-ILMethod {
    [outputtype([int])]
    param([int]$a, [int]$b)
    
    ldarg.0
    ldarg.1
    add
    ret
}

# Give the method a name
set-item function:myadd $sb
# Invoke it
myadd 1 2
# Invoke it again, notice that parameters are converted
myadd 3.1 4.2


# A new looping construct to use in our IL method bodies
function loopn
{
    param([int]$cnt, [scriptblock]$body)
    
    foreach ($i in 1..$cnt) {
        & $body
    }
}

# Use the new looping construct - a macro assembler!
& (New-ILMethod {
    [outputtype([int])]
    param()

    Ldc.I4.0
    loopn 42 {
        Ldc.I4.1
        add
    }
    ret
})
