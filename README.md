# Mintty4Julia
AutoHotkey script that starts Julia 1.3.1 (64bit) through Mintty 2.9.5 (64bit). CTRL+C without exiting Julia.

# Prerequisite:  
Must have 64bit Julia 1.3.1 installed at default location, ie: C:\Users\YourUserName\AppData\Local\Julia-1.3.1\bin\julia.exe

# How to Use:  
Unzip file and run mintty4julia.exe to start.  The file is zipped because I included all the Windows emojis (about 3000 of them!).

# How it Works:
mintty4julia.exe is an Autohotkey (https://www.autohotkey.com/) v2 interpreter renamed so that it will start the script file, mintty4julia.ahk, automatically.  The script has only been tested using Autohotkey 2.0-a108-a2fa0498 (64bit).  

Whenever you hit CTRL+C while the Julia window is in focus, it intercepts it and sends SIGINT directly to julia.exe via Windows API GenerateConsoleCtrlEvent.  See https://docs.microsoft.com/en-us/windows/console/generateconsolectrlevent and https://stackoverflow.com/questions/813086/can-i-send-a-ctrl-c-sigint-to-an-application-on-windows for more information.

The script also determines Julia's execution state through memory reading of its Mintty host.  This is done because a SIGINT sent while Julia is idle will cause it to exit.
