function CreatePassword {
    param(
        [int] 
        $length = 42
    )

    $characterList = 'a'..'z' + 'A'..'Z' + '0'..'9'

    do {
        $password = -join (0..$length | ForEach-Object { $characterList | Get-Random })
        [int]$hasLowerChar = $password -cmatch '[a-z]'
        [int]$hasUpperChar = $password -cmatch '[A-Z]'
        [int]$hasDigit = $password -match '[0-9]'

    }
    until (($hasLowerChar + $hasUpperChar + $hasDigit) -ge 3)

    return $password
}
