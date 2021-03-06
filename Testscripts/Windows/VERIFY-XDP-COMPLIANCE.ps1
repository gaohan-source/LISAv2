# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

<#
.Description
    This script deploys the VM, build and Install xdpdump application
    To verify xdp hook is working with current configuration.
#>

param([object] $AllVmData,
	[object] $CurrentTestData)

$MIN_KERNEL_VERSION = "5.6"
# RHEL kernel supports XDP since 4.18.0-214
$RHEL_MIN_KERNEL_VERSION = "4.18.0-213"

function Main{
    try{
        Write-LogInfo "VM details:"
        Write-LogInfo "  RoleName : $($allVMData.RoleName)"
        Write-LogInfo "  Public IP : $($allVMData.PublicIP)"
        Write-LogInfo "  SSH Port : $($allVMData.SSHPort)"
        Write-LogInfo "  Internal IP : $($allVMData.InternalIP)"

        $currentKernelVersion = Run-LinuxCmd -ip $allVMData.PublicIP -port $allVMData.SSHPort `
                -username $user -password $password -command "uname -r"
        if ($global:DetectedDistro -eq "UBUNTU"){
            if ((Compare-KernelVersion $currentKernelVersion $MIN_KERNEL_VERSION) -lt 0){
                Write-LogInfo "Unsupported kernel version: $currentKernelVersion"
                return $global:ResultSkipped
            }
        } elseif ($global:DetectedDistro -eq "REDHAT"){
            if ((Compare-KernelVersion $currentKernelVersion $RHEL_MIN_KERNEL_VERSION) -lt 0){
                Write-LogInfo "Unsupported kernel version: $currentKernelVersion"
                return $global:ResultSkipped
            }
        } else {
            Write-LogInfo "Unsupported distro: $($global:DetectedDistro)."
            return $global:ResultSkipped
        }

        # Provisioning VM
        Provision-VMsForLisa -allVMData $allVMData -installPackagesOnRoleNames "none"

        # Generate constants.sh and write all VM info into it
        Write-LogInfo "Generating constants.sh"
        $constantsFile = "$LogDir\constants.sh"
        Set-Content -Value "# Generated by Azure Automation." -Path $constantsFile
        Add-Content -Value "ip=$($allVMData.InternalIP)" -Path $constantsFile
        Add-Content -Value "nicName=eth1" -Path $constantsFile
        foreach ($param in $currentTestData.TestParameters.param) {
            Add-Content -Value "$param" -Path $constantsFile
        }

        Write-LogInfo "constants.sh created successfully..."
        Write-LogInfo (Get-Content -Path $constantsFile)

        #Build and Install XDP Dump application
        $installXDPCommand = @"
./XDPDumpSetup.sh 2>&1 > ~/xdpConsoleLogs.txt
. utils.sh
collect_VM_properties
"@
        Set-Content "$LogDir\StartXDPSetup.sh" $installXDPCommand
        Copy-RemoteFiles -uploadTo $allVMData.PublicIP -port $allVMData.SSHPort `
            -files "$constantsFile,$LogDir\StartXDPSetup.sh" `
            -username $user -password $password -upload -runAsSudo

        Run-LinuxCmd -ip $allVMData.PublicIP -port $allVMData.SSHPort `
            -username $user -password $password -command "chmod +x *.sh" -runAsSudo | Out-Null
        $testJob = Run-LinuxCmd -ip $allVMData.PublicIP -port $allVMData.SSHPort `
            -username $user -password $password -command "./StartXDPSetup.sh" `
            -RunInBackground -runAsSudo
        # Terminate process if ran more than 5 mins
        # TODO: Check max installation time for other distros when added
        $timer = 0
        while ((Get-Job -Id $testJob).State -eq "Running") {
            $currentStatus = Run-LinuxCmd -ip $allVMData.PublicIP -port $allVMData.SSHPort `
                -username $user -password $password `
                -command "tail -2 ~/xdpConsoleLogs.txt | head -1" -runAsSudo
            Write-LogInfo "Current Test Status: $currentStatus"
            Wait-Time -seconds 20
            $timer += 1
            if ($timer -gt 15) {
                Throw "XDPSetup did not stop after 5 mins. Please check logs"
            }
        }

        $finalStatus = Run-LinuxCmd -ip $allVMData.PublicIP -port $allVMData.SSHPort `
            -username $user -password $password -command "cat state.txt" -runAsSudo
        Copy-RemoteFiles -downloadFrom $allVMData.PublicIP -port $allVMData.SSHPort `
            -username $user -password $password -download `
            -downloadTo $LogDir -files " *.txt, *.log"
        if ($finalStatus -imatch "TestFailed") {
            Write-LogErr "Test failed. Last known status: $currentStatus."
            $testResult = "FAIL"
        }   elseif ($finalStatus -imatch "TestAborted") {
            Write-LogErr "Test Aborted. Last known status: $currentStatus."
            $testResult = "ABORTED"
        }   elseif ($finalStatus -imatch "TestSkipped") {
            Write-LogErr "Test Skipped. Last known status: $currentStatus"
            $testResult = "SKIPPED"
        }	elseif ($finalStatus -imatch "TestCompleted") {
            Write-LogInfo "Test Completed."
            Write-LogInfo "XDP build is Successful"
            $testResult = "PASS"
        }	else {
            Write-LogErr "Test execution is not successful, check test logs in VM."
            $testResult = "ABORTED"
        }
    } catch {
        $ErrorMessage =  $_.Exception.Message
        $ErrorLine = $_.InvocationInfo.ScriptLineNumber
        Write-LogErr "EXCEPTION : $ErrorMessage at line: $ErrorLine"
        $testResult = "FAIL"
    } finally {
        if (!$testResult) {
            $testResult = "ABORTED"
        }
        $resultArr += $testResult
    }
    Write-LogInfo "Test result: $testResult"
    return $testResult
}

Main
