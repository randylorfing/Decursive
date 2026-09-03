<#
    This file is part of ZDecursive, an independently maintained rebuild of Decursive.

    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    (Decursive AT 2072productions.com) (https://www.2072productions.com/to/decursive.php)
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

    ZDecursive is free software: you can redistribute it and/or modify it under
    the terms of the GNU General Public License as published by the Free Software
    Foundation, either version 3 of the License, or (at your option) any later
    version. ZDecursive is distributed without any warranty. See LICENSE.txt.
#>

[CmdletBinding()]
param(
    [string]$RetailRoot = (Join-Path ${env:ProgramFiles(x86)} 'World of Warcraft\_retail_'),
    [string]$OutputRoot = (Join-Path $env:TEMP 'ZDecursiveDiagnostics')
)

$ErrorActionPreference = 'Stop'

function Get-DiagnosticsTableText {
    param([string]$Text)

    $marker = 'ZDecursiveDiagnosticsDB'
    $start = $Text.IndexOf($marker, [StringComparison]::Ordinal)
    if ($start -lt 0) {
        throw 'ZDecursiveDiagnosticsDB was not found in the selected SavedVariables file.'
    }
    $start = $Text.IndexOf('{', $start)
    if ($start -lt 0) {
        throw 'The diagnostics table has no opening brace.'
    }
    $depth = 0
    $quote = [char]0
    $escaped = $false
    for ($index = $start; $index -lt $Text.Length; $index++) {
        $character = $Text[$index]
        if ($quote -ne [char]0) {
            if ($escaped) {
                $escaped = $false
            } elseif ($character -eq '\') {
                $escaped = $true
            } elseif ($character -eq $quote) {
                $quote = [char]0
            }
            continue
        }
        if ($character -eq '"' -or $character -eq "'") {
            $quote = $character
        } elseif ($character -eq '{') {
            $depth++
        } elseif ($character -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $Text.Substring($start, $index - $start + 1)
            }
        }
    }
    throw 'The diagnostics table is incomplete.'
}

function Convert-SafeLuaScalar {
    param([string]$Text)

    $value = $Text.Trim()
    if ($value -match '^"([A-Za-z0-9_.:+<>-]{1,80})"$') {
        return $Matches[1]
    }
    if ($value -match '^-?\d+(?:\.\d+)?$') {
        return [double]$value
    }
    if ($value -eq 'true') {
        return $true
    }
    if ($value -eq 'false') {
        return $false
    }
    return '<redacted>'
}

function Get-LuaTableEnd {
    param(
        [string]$Text,
        [int]$Start
    )

    if ($Start -lt 0 -or $Start -ge $Text.Length -or $Text[$Start] -ne '{') {
        return -1
    }
    $depth = 0
    $quote = [char]0
    $escaped = $false
    for ($index = $Start; $index -lt $Text.Length; $index++) {
        $character = $Text[$index]
        if ($quote -ne [char]0) {
            if ($escaped) {
                $escaped = $false
            } elseif ($character -eq '\') {
                $escaped = $true
            } elseif ($character -eq $quote) {
                $quote = [char]0
            }
            continue
        }
        if ($character -eq '"' -or $character -eq "'") {
            $quote = $character
        } elseif ($character -eq '{') {
            $depth++
        } elseif ($character -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $index
            }
        }
    }
    return -1
}

function Get-LuaTableRanges {
    param([string]$Text)

    $ranges = [System.Collections.Generic.List[object]]::new()
    $stack = [System.Collections.Generic.Stack[int]]::new()
    $quote = [char]0
    $escaped = $false
    for ($index = 0; $index -lt $Text.Length; $index++) {
        $character = $Text[$index]
        if ($quote -ne [char]0) {
            if ($escaped) {
                $escaped = $false
            } elseif ($character -eq '\') {
                $escaped = $true
            } elseif ($character -eq $quote) {
                $quote = [char]0
            }
            continue
        }
        if ($character -eq '"' -or $character -eq "'") {
            $quote = $character
        } elseif ($character -eq '{') {
            $stack.Push($index)
        } elseif ($character -eq '}') {
            if ($stack.Count -eq 0) {
                throw 'The diagnostics table contains an unmatched closing brace.'
            }
            $start = $stack.Pop()
            $ranges.Add([pscustomobject]@{
                Start = $start
                Length = $index - $start + 1
            })
        }
    }
    if ($stack.Count -ne 0 -or $quote -ne [char]0) {
        throw 'The diagnostics table contains an incomplete table or string.'
    }
    return $ranges
}

function Get-SafeLuaAssignments {
    param([string]$TableText)

    $assignments = [ordered]@{}
    if ($TableText.Length -lt 2 -or $TableText[0] -ne '{') {
        return $assignments
    }
    $index = 1
    while ($index -lt $TableText.Length - 1 -and $assignments.Count -lt 256) {
        while ($index -lt $TableText.Length - 1 -and ([char]::IsWhiteSpace($TableText[$index]) -or $TableText[$index] -eq ',')) {
            $index++
        }
        if ($index -ge $TableText.Length - 1) {
            break
        }
        if ($TableText[$index] -eq '{') {
            $nestedEnd = Get-LuaTableEnd -Text $TableText -Start $index
            if ($nestedEnd -lt 0) {
                throw 'The diagnostics table contains an incomplete nested value.'
            }
            $index = $nestedEnd + 1
            continue
        }
        if ($TableText[$index] -eq '"' -or $TableText[$index] -eq "'") {
            $quote = $TableText[$index]
            $index++
            $escaped = $false
            while ($index -lt $TableText.Length) {
                $character = $TableText[$index]
                if ($escaped) {
                    $escaped = $false
                } elseif ($character -eq '\') {
                    $escaped = $true
                } elseif ($character -eq $quote) {
                    $index++
                    break
                }
                $index++
            }
            continue
        }
        $remaining = $TableText.Substring($index)
        $keyMatch = [regex]::Match($remaining, '^\[\s*"([A-Za-z][A-Za-z0-9]{0,31})"\s*\]|^([A-Za-z][A-Za-z0-9]{0,31})')
        if (-not $keyMatch.Success) {
            $index++
            continue
        }
        $key = if ($keyMatch.Groups[1].Success) { $keyMatch.Groups[1].Value } else { $keyMatch.Groups[2].Value }
        $index += $keyMatch.Length
        while ($index -lt $TableText.Length - 1 -and [char]::IsWhiteSpace($TableText[$index])) {
            $index++
        }
        if ($index -ge $TableText.Length - 1 -or $TableText[$index] -ne '=') {
            continue
        }
        $index++
        while ($index -lt $TableText.Length - 1 -and [char]::IsWhiteSpace($TableText[$index])) {
            $index++
        }
        $valueStart = $index
        if ($TableText[$index] -eq '{') {
            $valueEnd = Get-LuaTableEnd -Text $TableText -Start $index
            if ($valueEnd -lt 0) {
                throw "The diagnostics value for $key has an incomplete table."
            }
            $assignments[$key] = $TableText.Substring($valueStart, $valueEnd - $valueStart + 1)
            $index = $valueEnd + 1
            continue
        }
        if ($TableText[$index] -eq '"' -or $TableText[$index] -eq "'") {
            $quote = $TableText[$index]
            $index++
            $escaped = $false
            while ($index -lt $TableText.Length) {
                $character = $TableText[$index]
                if ($escaped) {
                    $escaped = $false
                } elseif ($character -eq '\') {
                    $escaped = $true
                } elseif ($character -eq $quote) {
                    $index++
                    break
                }
                $index++
            }
            $assignments[$key] = $TableText.Substring($valueStart, $index - $valueStart)
            continue
        }
        while ($index -lt $TableText.Length - 1 -and $TableText[$index] -ne ',' -and $TableText[$index] -ne '}') {
            $index++
        }
        $assignments[$key] = $TableText.Substring($valueStart, $index - $valueStart).Trim()
    }
    return $assignments
}

$savedVariablesRoot = Join-Path $RetailRoot 'WTF\Account'
if (-not (Test-Path -LiteralPath $savedVariablesRoot -PathType Container)) {
    throw 'The Retail SavedVariables root was not found.'
}

$candidate = Get-ChildItem -LiteralPath $savedVariablesRoot -File -Recurse |
    Where-Object { $_.Name -eq 'ZDecursive.lua' -or $_.Name -eq 'ZDecursive.lua.bak' } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

if (-not $candidate) {
    throw 'No ZDecursive SavedVariables file was found.'
}

$content = Get-Content -LiteralPath $candidate.FullName -Raw
$tableText = Get-DiagnosticsTableText -Text $content
if ($tableText.Length -gt 2MB) {
    throw 'The diagnostics table exceeds the restricted parser size limit.'
}
if ($tableText -match '(?i)\b(function|loadstring|dofile|require|setfenv|getfenv)\b') {
    throw 'The diagnostics table contains executable Lua and was rejected.'
}

$rootAssignments = Get-SafeLuaAssignments -TableText $tableText
$records = [System.Collections.Generic.List[object]]::new()
$ranges = Get-LuaTableRanges -Text $tableText | Sort-Object Length
foreach ($range in $ranges) {
    if ($range.Length -gt 65536) {
        continue
    }
    $recordText = $tableText.Substring($range.Start, $range.Length)
    $record = Get-SafeLuaAssignments -TableText $recordText
    $required = @('sequence', 'session', 'stamp', 'version', 'kind', 'fields')
    $complete = $true
    foreach ($key in $required) {
        if (-not $record.Contains($key)) {
            $complete = $false
            break
        }
    }
    if (-not $complete -or $record.sequence -notmatch '^\d+$' -or $record.session -notmatch '^\d+$' -or $record.fields -notmatch '^\s*\{') {
        continue
    }
    $fields = [ordered]@{}
    $fieldAssignments = Get-SafeLuaAssignments -TableText $record.fields
    foreach ($fieldName in $fieldAssignments.Keys | Select-Object -First 64) {
        $fields[$fieldName] = Convert-SafeLuaScalar $fieldAssignments[$fieldName]
    }
    $records.Add([ordered]@{
        sequence = [int64]$record.sequence
        session = [int64]$record.session
        stamp = Convert-SafeLuaScalar $record.stamp
        version = Convert-SafeLuaScalar $record.version
        kind = Convert-SafeLuaScalar $record.kind
        fields = $fields
    })
    if ($records.Count -gt 960) {
        throw 'The diagnostics record count exceeds the bounded storage contract.'
    }
}
$records = @($records | Sort-Object sequence)

$summary = [ordered]@{
    schema = if ($rootAssignments.schema -match '^\d+$') { [int]$rootAssignments.schema } else { $null }
    lastSession = if ($rootAssignments.lastSession -match '^\d+$') { [int64]$rootAssignments.lastSession } else { $null }
    sourceModifiedUtc = $candidate.LastWriteTimeUtc.ToString('o')
    sourceBytes = $candidate.Length
    recordCount = $records.Count
    records = $records
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonPath = Join-Path $OutputRoot "ZDecursive-diagnostics-$stamp.json"
$textPath = Join-Path $OutputRoot "ZDecursive-diagnostics-$stamp.txt"
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding utf8
@(
    'ZDecursive diagnostics summary'
    "Schema: $($summary.schema)"
    "Last session: $($summary.lastSession)"
    "Source modified UTC: $($summary.sourceModifiedUtc)"
    "Source bytes: $($summary.sourceBytes)"
    "Sanitized records: $($summary.recordCount)"
    "JSON output: $jsonPath"
) | Set-Content -LiteralPath $textPath -Encoding utf8

[pscustomobject]@{
    Json = $jsonPath
    Summary = $textPath
    Records = $records.Count
}
