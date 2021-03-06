##############################################################################################
# AnalysisAllResults.ps1
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.
# Operations :
#
<#
.SYNOPSIS
    This script authenticates PS session using All test results analysis.
    This script checks contents of the ./Report/*-junit.xml files and exit
    with zero or non-zero exit code.

.PARAMETER

.INPUTS

.NOTES
    Creation Date:
    Purpose/Change:

.EXAMPLE
#>
###############################################################################################
$LogFileName = "AnalyseAllResults.log"
#Import Libraries.
if (!$global:LogFileName){
    Set-Variable -Name LogFileName -Value $LogFileName -Scope Global -Force
}
Get-ChildItem .\Libraries -Recurse | Where-Object { $_.FullName.EndsWith(".psm1") } | ForEach-Object { Import-Module $_.FullName -Force -Global -DisableNameChecking }

$allReports = Get-ChildItem .\Report | Where-Object {($_.FullName).EndsWith("-junit.xml") -and ($_.FullName -imatch "\d\d\d\d\d\d")}
$retValue = 0
foreach ( $report in $allReports )
{
    Write-LogInfo "Analyzing $($report.FullName).."
    $resultXML = [xml](Get-Content "$($report.FullName)" -ErrorAction SilentlyContinue)
    if ( ( $resultXML.testsuites.testsuite.failures -eq 0 ) -and ( $resultXML.testsuites.testsuite.errors -eq 0 ) -and ( $resultXML.testsuites.testsuite.tests -gt 0 ))
    {
    }
    else
    {
        $retValue = 1
    }
    foreach ($testcase in $resultXML.testsuites.testsuite.testcase)
    {
        if ($testcase.failure)
        {
            Write-LogInfo "$($testcase.name) : FAIL"
        }
        else
        {
            Write-LogInfo "$($testcase.name) : PASS"
        }
    }
    Write-LogInfo "----------------------------------------------"
}
Write-LogInfo "Exiting with Code : $retValue"
exit $retValue
