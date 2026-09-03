<#
    This file is part of ZDecursive, an independently maintained rebuild of Decursive.

    Based on Decursive, Copyright (C) 2006-2026 John Wellesz
    (Decursive AT 2072productions.com) (https://www.2072productions.com/to/decursive.php)
    ZDecursive rebuild and ongoing maintenance, Copyright (C) 2026 Randy Lorfing

    ZDecursive is free software: you can redistribute it and/or modify it under
    the terms of the GNU General Public License as published by the Free Software
    Foundation, either version 3 of the License, or (at your option) any later
    version. ZDecursive is distributed without any warranty. See ../LICENSE.
#>

$ErrorActionPreference = 'Stop'

function Assert-Contract {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$temporaryRoot = Join-Path $env:TEMP ("ZDecursive-export-contract-" + [guid]::NewGuid().ToString('N'))
$retailRoot = Join-Path $temporaryRoot 'Retail'
$savedVariables = Join-Path $retailRoot 'WTF\Account\Contract\SavedVariables'
$outputRoot = Join-Path $temporaryRoot 'Output'
$exporter = Join-Path (Get-Location) 'ZDecursive\Tools\Export-ZDecursiveDiagnostics.ps1'

try {
    New-Item -ItemType Directory -Path $savedVariables -Force | Out-Null
    $fixture = Join-Path (Get-Location) 'tests\fixtures\retail\WTF\Account\Example\SavedVariables\ZDecursive.lua'
    Copy-Item -LiteralPath $fixture -Destination (Join-Path $savedVariables 'ZDecursive.lua')

    $result = & $exporter -RetailRoot $retailRoot -OutputRoot $outputRoot
    Assert-Contract ($result.Records -eq 1) 'exporter did not find exactly one arbitrarily ordered record'
    $json = Get-Content -LiteralPath $result.Json -Raw | ConvertFrom-Json
    Assert-Contract ($json.recordCount -eq 1) 'JSON record count is not exact'
    Assert-Contract ($json.schema -eq 1 -and $json.lastSession -eq 7) 'root metadata was not parsed'
    Assert-Contract ($json.records[0].sequence -eq 12 -and $json.records[0].kind -eq 'ROSTER_CONVERGENCE') 'record content is wrong'
    Assert-Contract ($json.records[0].fields.count -eq 2 -and $json.records[0].fields.result -eq 'APPLIED') 'record fields are wrong'
    Assert-Contract ($json.records[0].fields.private -eq '<redacted>') 'unsafe scalar was not redacted'
    Write-Output 'export-diagnostics-contract: ok'
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
