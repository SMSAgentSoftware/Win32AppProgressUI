##################################################
## INTUNE WIN32 APP PROGRESS UI TEMPLATE SCRIPT ##
##################################################

## NOTES:
# This is a template script for how to display a progress UI during scripted installs for Win32 applications
# Make sure to package the 'Win32 App Script Progress UI.exe' with your script!

# Parameters
$ApplicationName = "My app name" # The app name as displayed in the progress UI. Should match the name of the Win32 app in Intune
$TotalSteps = "2" # The total number of major steps, ie individual tasks such as downloads, installs etc, in this script
$ProgressPreference = 'SilentlyContinue'


###############
## FUNCTIONS ##
###############
#region Functions
# Creates and triggers a scheduled task to run the progress UI in the logged-on user context.
function Display-ProgressUI{
    # Create the VBScript silent wrapper    
    $VBScriptContent = @"
p = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
location = p &"\"& WScript.Arguments(0)
command = "powershell.exe -nologo -ExecutionPolicy Bypass -File """ &location &""""
set shell = CreateObject("WScript.Shell")
shell.Run command,0
"@
    try 
    {
        $VBScriptContent | Out-File -FilePath "$WorkingDirectory\Invoke-PSScript.vbs" -Force -ErrorAction Stop 
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Set the exe location
    $exe = "$WorkingDirectory\Win32 App Script Progress UI.exe"

    # Create the script definition
    $ScriptContent = @"
# Start the notification process
`$Process = Start-Process -FilePath "$Exe" -NoNewWindow -PassThru
"@
    try 
    {
        $ScriptContent | Out-File -FilePath "$WorkingDirectory\Show-Win32AppProgressUI.ps1" -Force -ErrorAction Stop 
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Create the scheduled task definition
    $XMLContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo>
    <Date>2023-04-06T17:58:00.6687247</Date>
    <Author>HenrySmith</Author>
    <URI>\Show-Win32AppProgressUI</URI>
</RegistrationInfo>
<Triggers />
<Principals>
    <Principal id="Author">
    <GroupId>S-1-5-32-545</GroupId>
    <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
</Principals>
<Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
    <StopOnIdleEnd>false</StopOnIdleEnd>
    <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
</Settings>
<Actions Context="Author">
    <Exec>
    <Command>$WorkingDirectory\Invoke-PSScript.vbs</Command>
    <Arguments>Show-Win32AppProgressUI.ps1</Arguments>
    </Exec>
</Actions>
</Task>
"@
    try 
    {
        $XMLContent | Out-File -FilePath "$WorkingDirectory\Show-Win32AppProgressUI.xml" -Force -ErrorAction Stop 
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Create the scheduled task
    try 
    {
        $null = Register-ScheduledTask -Xml (Get-Content "$WorkingDirectory\Show-Win32AppProgressUI.xml" -ErrorAction Stop | out-string) -TaskName "Show-Win32AppProgressUI" -TaskPath "\"  -Force -ErrorAction Stop
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

    # Start the scheduled task
    try 
    {
        $null = Start-ScheduledTask -TaskName "Show-Win32AppProgressUI" -TaskPath "\" -ErrorAction Stop
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }  

    # Wait for task to start
    Start-Sleep -Seconds 5

    # Cleanup task
    try 
    {
        Unregister-ScheduledTask -TaskName "Show-Win32AppProgressUI" -TaskPath "\" -Confirm:$false -ErrorAction Stop
    }
    catch 
    {
        return "Failed: $($_.Exception.Message)"
    }

}

# Invokes the cleanup of files
function Invoke-Cleanup {
    # This part needs a separate process as the progress UI exe can't be deleted if its running
    $Code = "
    `$ProgressUIProcess = Get-Process -Name 'Win32 App Script Progress UI' -ErrorAction SilentlyContinue
    If (`$ProgressUIProcess)
    {
        # Wait for the UI to close, or timeout
        `$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        do{ Start-Sleep -Seconds 1 }
        until (`$ProgressUIProcess.HasExited -eq `$true -or `$Stopwatch.Elapsed.TotalSeconds -ge 300)
        If (`$ProgressUIProcess.HasExited -eq `$true)
        {
            [System.IO.Directory]::Delete(""$WorkingDirectory"",`$true)
        }
    }
    else 
    {
        [System.IO.Directory]::Delete(""$WorkingDirectory"",`$true)
    }
    "
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code))
    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new("PowerShell.exe","-EncodedCommand $encodedCommand")
    $StartInfo.CreateNoWindow = $true 
    $StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    [void][System.Diagnostics.Process]::Start($StartInfo)
}
#endregion


#################
## PREPARATION ##
#################
#region Preparation
# Create a user-accessible temp location to save the files needed for the progress UI. This will be cleaned up after.
$TempDirectoryName = [guid]::NewGuid().Guid.SubString(0,8)
$script:WorkingDirectory = "$env:ProgramData\$TempDirectoryName"
if (-not ([System.IO.Directory]::Exists($WorkingDirectory)))
{
    [void][System.IO.Directory]::CreateDirectory($WorkingDirectory)
}

# Copy Win32 App Script Progress UI.exe to temp location where the user has permissions to run it
[System.IO.File]::Copy("$PSScriptRoot\Win32 App Script Progress UI.exe","$WorkingDirectory\Win32 App Script Progress UI.exe",$true)

# Set the initial values for the progress UI - must set these before displaying the UI
$Path = "SOFTWARE\SMSAgent\Win32AppProgressUI" # this location is hard-coded in the progress UI exe - do not change it
$script:Key = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($Path)
$Key.SetValue("AppName",$ApplicationName)
$Key.SetValue("TotalSteps",$TotalSteps)
$Key.SetValue("CurrentStatus","Running")
# Blank these ones from any previous run
$Key.SetValue("StepName","")
$Key.SetValue("StepNumber","")
$Key.SetValue("StepSeverity","")

# Start the Progress UI
Display-ProgressUI
#endregion


####################
## EXAMPLE STEP 1 ##
####################
#region Step1
# Send the step name and severity to the progress UI
$Key.SetValue("StepName","Downloading application X")
$Key.SetValue("StepSeverity","Information") # Possible values are: Information, Warning, Error.

$URL = "https://corretto.aws/downloads/latest/amazon-corretto-8-x64-windows-jdk.msi"
$Filename = $URL.Split('/')[-1]
$Destination = "$WorkingDirectory\$Filename"
try 
{
    Start-BitsTransfer -Source $URL -Destination $Destination -DisplayName "$Filename" -Priority Foreground -ErrorAction Stop
}
catch 
{
    # If you're catching an error that will stop the script here, set the StepName to include the error details...
    $key.SetValue("StepName", "The BITS transfer for $Filename failed: $($_.Exception.Message)")
    # ...and set the CurrentStatus to 'Error'. This will add a 'Close' button to the progress UI allowing the user time to review the error and close the UI themselves.
    $key.SetValue("CurrentStatus", "Error")
    # Then invoke the cleanup to remove temporary files for the progress UI
    Invoke-Cleanup
    Exit 1
}
# Set the StepNumber to indicate this step is complete
$Key.SetValue("StepNumber","1")
#endregion


####################
## EXAMPLE STEP 2 ##
####################
#region Step2
# Send the next step name to the progress UI
$Key.SetValue("StepName","Installing application X")

$InstallTimeoutSeconds = 300
$InstallerStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
do {
    try 
    {
        $Process = Start-Process -FilePath msiexec.exe -ArgumentList @("/i ""$WorkingDirectory\$Filename""","/qn","REBOOT=ReallySuppress") -NoNewWindow -PassThru -Wait -ErrorAction Stop
    }
    catch 
    {
        $key.SetValue("StepName", "Failed to start installation process for $Filename`: $($_.Exception.Message)")
        $key.SetValue("CurrentStatus", "Error")
        Invoke-Cleanup
        Exit 1
    }
}
Until ($Process.HasExited -eq $true -or $InstallerStopwatch.Elapsed.TotalSeconds -ge $InstallTimeoutSeconds)
$InstallerStopwatch.Stop()
If ($InstallerStopwatch.Elapsed.TotalSeconds -ge $InstallTimeoutSeconds)
{
    $key.SetValue("StepName", "Installation of $Filename exceeded the timeout value")
    $key.SetValue("CurrentStatus", "Error")
    Invoke-Cleanup
    Exit 1
}
# Increment the StepNumber to indicate this step is complete
$Key.SetValue("StepNumber","2")
#endregion


###############
## FINISH UP ##
###############
# To finish, set the StepName to 'Completed' or something similar...
$Key.SetValue("StepName","Completed")
# ...and set the CurrentStatus to 'Completed'. This will trigger the progress UI to stop its timer, wait for 5 seconds, then automatically exit.
$Key.SetValue("CurrentStatus","Completed")
# Don't forget to cleanup temp files!
Invoke-Cleanup
