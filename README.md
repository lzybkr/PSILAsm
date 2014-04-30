ILAsm in PowerShell
===================

This module demonstrates a way to use MSIL directly in PowerShell,
similar to ILASM.  It's roughly like inline asm in C++, but for .Net.

Here is an example of how you would use it:

```
# Create a ScriptBlock wrapping a dynamic method whose implementation
# is the IL emitted by evaluating the body.  The method signature is
# deduced by [OutputType] and the param statement, but you don't
# use the PowerShell parameters explicitly, they are just a signature.

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
```
