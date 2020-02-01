# Mintty4Julia
AutoHotkey script that starts Julia through Mintty 2.9.5 (64bit)
- Ctrl + C interrupts running Julia routine without crashing/exiting Julia/Mintty
- Starts .jl files dragged-n-dropped onto startJulia.exe (each working directory set to same path as .jl file)
- Finds latest installed version of Julia automatically (unless specified in config.txt)
- Nearly 3000 Windows emojis preinstalled (matches the emojis in VS-code)
- Supports several versions of Julia (tested on 1.3.1 64bit, 1.4.0rc1 64bit)

## Prerequisite:  
Must have Julia installed at default location, ie: C:\Users\YourUserName\AppData\Local\Julia-1.3.1\bin\julia.exe, or provide path to Julia's bin folder in config.txt.

## How to Use:  
1. Download this repository. 
2. Unzip files maintaining their folder structure.
3. To start Julia, do one of the following:
    * Run startJulia.ahk.exe
    * Or Drag and drop .jl files onto startJulia.exe
    * Note: If Julia fails to start, create config.txt with the absolute path of Julia's bin folder.

    Tip:  You can create a Windows shortcut of startJulia.exe

## How it Works:
This script is written using Autohotkey v2 (https://www.autohotkey.com/) version 2.0-a108-a2fa0498 (64bit).  startJulia.ahk.exe is a wrapper that forwards drag and drop parameters to startJulia.ahk.  You can inspect its source through a hex editor.  Its source is also provided as startJulia.ahk.exe.src. 

This script intercepts Ctrl+C and uses Windows API (GenerateConsoleCtrlEvent) to send SIGINT directly to julia.exe.  See https://docs.microsoft.com/en-us/windows/console/generateconsolectrlevent and https://stackoverflow.com/questions/813086/can-i-send-a-ctrl-c-sigint-to-an-application-on-windows for more information.

The script determines Julia's execution state by accessing a static memory location of its Mintty host.  This is done to prevent Julia from crashing when a SIGINT event is sent while Julia is idle.  The memory address used appears to be static for the provided mintty.exe (2.9.5 x86_64-pc-cygwin) regardless of julia.exe's version.

For each targeted Mintty Terminal Window, the script uses the window's process ID to identify its child process (mintty.exe), which then leads to the identification of the grandchild process (julia.exe).  This is made possible by enumerating a list of all active processes along with their process ID's and parent process ID's.

## FAQ
Why Mintty 2.9.5, and where did you get it from? 

A:  This version of Mintty is taken from a portable Cygwin build (https://github.com/MachinaCore/CygwinPortable).  It is the only readily available binary I found that plays well with Julia and is capable of displaying emojis inside the REPL.

## Change Log:
 - Added support for drag and drop
 - Added support for multiple versions of Julia
 - Added auto path finding for Julia's bin folder and the ability to specify one in config.txt
