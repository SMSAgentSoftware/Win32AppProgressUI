# Win32AppProgressUI
### _Displays a progress UI during Intune Win32 app scripted installs_

***Win32 App Script Progress UI*** is a simple .Net Framework executable that can be included in your Intune Win32 app scripted installs to provide a visual indicator of progress. It works best for scripted installations with multiple steps that overall take long enough that you want to provide some visual indication of progress to improve the user experience. In this way, the user is not just left staring at the "Installing..." status in the Company Portal wondering if anything is actually happening...!

![alt text](https://github.com/SMSAgentSoftware/Win32AppProgressUI/blob/main/Screenshots/2023-09-11_16-36-38.gif?raw=true)

### Requirements
- 64-bit Windows 10 or later
- Intune Win32 app running in SYSTEM context

### How it works
The progress UI is called by the PowerShell script wrapper and watches registry keys that are used to update the UI, such as the step name, the severity (Information, Warning, Error), the overall progress etc. It uses a scheduled task running as 'Users' to display the UI in the context of the logged-on user.

Steps can be reported with different severities if needed, such as Information for a regular step:

![alt text](https://github.com/SMSAgentSoftware/Win32AppProgressUI/blob/main/Screenshots/Info.png?raw=true)

A Warning:

![alt text](https://github.com/SMSAgentSoftware/Win32AppProgressUI/blob/main/Screenshots/Warning.png?raw=true)

An Error. If the script fails and you want to exit early, you set the ***CurrentStatus*** to ***Error*** and it will stop the progress UI timer and leave a ***Close*** button to allow the user time to review the error.

![alt text](https://github.com/SMSAgentSoftware/Win32AppProgressUI/blob/main/Screenshots/Error.png?raw=true)

When the script is completed, set the ***CurrentStatus*** to ***Completed*** and the progress UI will stop the timer, wait 5 seconds, then close.

![alt text](https://github.com/SMSAgentSoftware/Win32AppProgressUI/blob/main/Screenshots/Completed.png?raw=true)

### How to use it
Download the release package and download the ***Install*** script in the ***Template script*** folder. The template script contains all the code you need to use the progress UI including example steps that demonstrate how to set the UI progress values. Replace the example steps between the ***Preparation*** and ***Finish Up*** code regions with your own installation logic.

Package both the ***Win32 App Script Progress UI.exe*** and ***Install.ps1*** into a Win32 application.

**Important**: set the __Install command__ in the Win32 app to call the 64-bit version of PowerShell, otherwise it won't read the registry keys, eg
__%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -File .\Install.ps1__
