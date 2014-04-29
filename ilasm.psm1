
# Create an empty hash
$operandTypeHandlers = @{}

$myModule = $MyInvocation.MyCommand.ScriptBlock.Module

# Opcodes that take no operands
$operandTypeHandlers[[System.Reflection.Emit.OperandType]::InlineNone] =
{
    $null = (& $myModule gv -ValueOnly ilEmitter).Emit($opcode)
}

# Opcodes that take one integer operand
$operandTypeHandlers[[System.Reflection.Emit.OperandType]::InlineI] =
{
    param([int]$i)
    $null = (& $myModule gv -ValueOnly ilEmitter).Emit($opcode, $i)
}

# Opcodes that take one large integer operand
$operandTypeHandlers[[System.Reflection.Emit.OperandType]::InlineI8] =
{
    param([long]$i)
    $null = (& $myModule gv -ValueOnly ilEmitter).Emit($opcode, $i)
}

# Opcodes that take one float operand
$operandTypeHandlers[[System.Reflection.Emit.OperandType]::ShortInlineR] =
{
    param([float]$r)
    $null = (& $myModule gv -ValueOnly ilEmitter).Emit($opcode, $r)
}

# Opcodes that take one double operand
$operandTypeHandlers[[System.Reflection.Emit.OperandType]::InlineR] =
{
    param([double]$r)
    $null = (& $myModule gv -ValueOnly ilEmitter).Emit($opcode, $r)
}

# TODO: add handlers for all operand types

# Get a list of MemberDefinitions for every opcode
$opcodes = [System.Reflection.Emit.OpCodes] | get-member -Static -MemberType Property

# Define a function for every opcode that emits il
foreach ($property in $opcodes)
{
    # $property is a MemberDefinition, to get an Opcode,
    # we must call the property
    $opcode = [System.Reflection.Emit.OpCodes]::$($property.Name)
    
    # Unsupported operand types will raise an exception, in a fully featured
    # assembler we wouldn't need this test.
    if ($operandTypeHandlers[$opcode.OperandType] -eq $null)
    {
        $script = { throw "Unsupported opcode: $($property.Name)" }
    }
    else
    {
        $script = $operandTypeHandlers[$opcode.OperandType].GetNewClosure()
    }

    set-item -Path "function:$($opcode.Name)" -Value $script
    Export-ModuleMember -Function $opcode.Name
}


function New-ILMethod
{
    param([scriptblock]$Body)
    
    $returnType = ($body.Attributes |
        ? { $_ -is [System.Management.Automation.OutputTypeAttribute] } |
        select -first 1).Type[0].Type
    if ($returnType -eq $null)
    {
        $returnType = [void]
    }

    $method = [guid]::NewGuid().ToString()

    set-item -path "function:$method" $body
    $parameters = (gcm $method).Parameters.Values
    $params = [type[]]@($parameters | % { $_.ParameterType })

    # Create a dynamic method with the signature:
    #    int DynamicILMethod()
    $dynamicMethod = new-object System.Reflection.Emit.DynamicMethod `
                                     "DynamicILMethod",$returnType,$params
    $script:ilEmitter = $dynamicMethod.GetILGenerator()
    
    # Generate the body - note - no error checking on the body because
    # it's just a script block
    & $Body

    remove-item -path "function:$method"

    $bodyText = "param("
    $sep = ""
    foreach ($p in $parameters)
    {
        $bodyText += '{2}[{0}]${1}' -f $p.ParameterType,$p.Name,$sep
        $sep = ", "
    }
    $bodyText += ") "
    $bodyText += ' $dynamicMethod.Invoke($null,'
    if ($parameters.Count) {
        $bodyText += "@("
        $sep = ""
        foreach ($p in $parameters)
        {
            $bodyText += '{0}${1}' -f $sep,$p.Name
            $sep = ", "
        }
        $bodyText += ")"
    } else {
        $bodyText += '$null'
    }
    $bodyText += ")"
    
    $ilFunction = [ScriptBlock]::Create($bodyText).GetNewClosure()
    return $ilFunction
}    

Export-ModuleMember -Function New-ILMethod