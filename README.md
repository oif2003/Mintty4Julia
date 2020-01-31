# Mintty4Julia
AutoHotkey script that starts Julia 1.3.1 (64bit) through Mintty 2.9.5 (64bit). CTRL+C without exiting Julia.

## Prerequisite:  
Must have 64bit Julia 1.3.1 installed at default location, ie: C:\Users\YourUserName\AppData\Local\Julia-1.3.1\bin\julia.exe

## How to Use:  
Unzip file and run mintty4julia.exe to start Julia with Mintty.  Nearly 3000 Windows emojis are included, hence the zip file.  You may start multiple copies of Mintty/Julia.  The script will exit once all instances of Mintty/Julia have been terminated.

## How it Works:
mintty4julia.exe is a renamed copy of Autohotkey (https://www.autohotkey.com/) v2's executable.  This is done to allow mintty4julia.ahk to be auto-launched by mintty4julia.exe without compiling the script.  The script should be used with Autohotkey 2.0-a108-a2fa0498 (64bit).  

This script intercepts CTRL+C and uses Windows API (GenerateConsoleCtrlEvent) to send SIGINT directly to julia.exe.  See https://docs.microsoft.com/en-us/windows/console/generateconsolectrlevent and https://stackoverflow.com/questions/813086/can-i-send-a-ctrl-c-sigint-to-an-application-on-windows for more information.

The script determines Julia's execution state by accessing a static memory location of its Mintty host.  This is done to prevent Julia from crashing when a SIGINT event is sent while Julia is idle.  Because this script relies on fixed memory locations of Mintty (and possibily Julia), it should only be used in its current configuration, namely with Mintty 2.9.5 (x86_64-pc-cygwin) and Julia 1.3.1 64bit.

For each targeted Mintty Terminal Window, the script uses the window's process ID to identify its child process (mintty.exe), which then leads to the identification of the grandchild process (julia.exe).  This is made possible by enumerating a list of all active processes along with their process ID's and parent process ID's.

## FAQ
Why Mintty 2.9.5, and where did you get it from? 

A:  This version of Mintty is taken from a portable Cygwin build (https://github.com/MachinaCore/CygwinPortable).  It is the only readily available binary I found that can display emojis inside Julia REPL and have a semblance of stability.
