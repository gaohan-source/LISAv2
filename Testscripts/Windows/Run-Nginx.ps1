# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

param(
    [object] $AllVmData,
    [object] $CurrentTestData,
    [object] $TestProvider,
    [object] $TestParams
)

function Main {
    param (
        [object] $AllVmData,
        [object] $CurrentTestData,
        [object] $TestProvider,
        [object] $TestParams
    )

    $currentTestResult = Create-TestResultObject
    $resultArr = @()

    try {
        $null = Collect-TestLogs -LogsDestination $LogDir -TestType "sh" `
            -PublicIP $AllVmData.PublicIP -SSHPort $AllVmData.SSHPort `
            -Username $user -password $password `
            -TestName $currentTestData.testName

        $statusLogPath = Join-Path $LogDir "state.txt"
        $currentResult = Get-Content $statusLogPath
        if (($currentResult -imatch "TestAborted") -or ($currentResult -imatch "TestRunning")) {
            Write-LogErr "Test aborted. Last known status : $currentResult"
            $resultArr += "ABORTED"
            $CurrentTestResult.TestSummary += New-ResultSummary -testResult $currentResult -metaData $metaData `
                -checkValues "PASS,FAIL,ABORTED" -testName $CurrentTestData.testName
        } else {
            $resultArr += "PASS"
        }
    } catch {
        $errorMessage =  $_.Exception.Message
        $errorLine = $_.InvocationInfo.ScriptLineNumber
        Write-LogInfo "EXCEPTION : $errorMessage at line: $errorLine"
    } finally {
        if (!$resultArr) {
            $resultArr += "ABORTED"
        }
    }

    $currentTestResult.TestResult = Get-FinalResultHeader -resultarr $resultArr
    return $currentTestResult

}

Main -AllVmData $AllVmData -CurrentTestData $CurrentTestData -TestProvider $TestProvider `
    -TestParams (ConvertFrom-StringData $TestParams.Replace(";","`n"))