; mintty4julia.ahk
; Designed to work with Mintty 2.9.5 (x86_64-pc-cygwin) and Julia 1.3.1 64bit. 
; See https://github.com/oif2003/Mintty4Julia for more information.

#SingleInstance Force
TraySetIcon(A_ScriptDir "\julia.ico")

;=============================================
; Auto-execute Section
;=============================================

;How long to wait between before we turn off "God-mode".  Increase if script starts killing itself.
GOD_MODE_OFF_DELAY := 1000

;Memory offset constants
MINTTY_VERSION  := 0x100462310
JULIA_EXE_STATE := 0x100497FA0

cygwinBin  := A_ScriptDir "\CygwinPortable\App\Runtime\Cygwin\bin"

juliaBinPathConfig := "config.txt"
if FileExist(juliaBinPathConfig) {
	juliaBin := FileRead(juliaBinPathConfig)
} else {
	Loop Files, StrReplace(A_AppData, "Roaming") "Local\*", "D"					
		if InStr(A_LoopFileFullPath, "\AppData\Local\Julia-") 
			folderList .= A_LoopFileFullPath "`n"
	juliaBin := StrSplit(Sort(folderList, "R")	, "`n")[1] "\bin"
}
FileExist(juliaBin) ? "Continue Execution" : abort("Julia's bin folder not found!")

;Rename user directory otherwise Windows emojis will not load.								
Loop Files, A_ScriptDir "\CygwinPortable\App\Runtime\Cygwin\home\*", "D"						
	folderpath := A_LoopFileFullPath															 
DirMove(folderpath, A_ScriptDir "\CygwinPortable\App\Runtime\Cygwin\home\" A_UserName, "R")

;Set path to Cygwin's bin folder for Mintty, and start Julia using VBScript. 
shell := ComObjCreate("WScript.Shell")
exec := shell.Exec(A_ComSpec)
exec.StdIn.Write(Format('SET PATH=%PATH%;"{}";"{}"`n', cygwinBin, juliaBin))
if A_Args.Length > 0
	for _, filePath in A_Args {
		SplitPath(filePath, , workDir)
		exec.StdIn.Write(Format('START /D "{}" mintty.exe julia.exe --banner=no -i "{}"`n', workDir, filePath))
	}
else {
	workDir := StrReplace(A_ScriptDir, "\Resources")
	exec.StdIn.Write(Format('START /D "{}" mintty.exe julia.exe', workDir))
}
exec.StdIn.Write("`nexit`n")

;Allow julia.exe time to load.  So VBScript's exit event will kill us. 
WinWait("julia.exe")	

;Register this script to get notified of events to listen for WINDOWDESTROYED message
DllCall("RegisterShellHookWindow", "ptr", A_ScriptHwnd)
msgID := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
OnMessage(msgID, "shellMessage")

;We probably don't need this but just in case...
;DetectHiddenWindows True	



;=============================================
; Function Definitons
;=============================================

;Helper function that collects information on "julia.exe" and "mintty.exe" processes.
;Returns an object containing two keys: mintty and julia.
getListOfJuliaMinttyProcesses() {
	juliaProcesses := Array()
	minttyProcesses := Array()
	
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
		if process.Name == "julia.exe" 
				juliaProcesses.Push({PID:process.ProcessId, ParentPID:process.ParentProcessId})
		else if process.Name == "mintty.exe"
				minttyProcesses.Push({PID:process.ProcessId, ParentPID:process.ParentProcessId})

	return {mintty:minttyProcesses, julia:juliaProcesses}
}

;Finds the julia.exe process associated with the active Mintty window.  The logic is as follow:
;Active Mintty window PID -> Hidden Mintty window PID -> julia.exe PID
findJuliaPID(activeMinttyPID) {	
	processes:= getListOfJuliaMinttyProcesses()
	
	for _, m in processes.mintty
		if m.ParentPID == activeMinttyPID
			for _, j in processes.julia
				if j.ParentPID == m.PID
					return j.PID
}

;Same logic as above, but checks all existing Mintty and Julia instances for associated sets.
;If none are found, returns true.
allMinttiesHaveDied() {
	processes:= getListOfJuliaMinttyProcesses()
	
	for _, m1 in processes.mintty
		for _, m2 in processes.mintty
			if m2.ParentPID == m1.PID
				for _, j in processes.julia
					if j.ParentPID == m2.PID
						return false
	return true
}

;Fires whenever a window is destroyed.  Scripts exits after all Mintty+Julia instances are terminated.
shellMessage(wParam, *) {
	if wParam == 2 {	;HSHELL_WINDOWDESTROYED 
		if allMinttiesHaveDied() {	;(
			DllCall("DeregisterShellHookWindow", "ptr", A_ScriptHwnd)
			ExitApp()
		}
	}
}

abort(errorMsg) {
	throw Exception(errorMsg, -1)
}

;=============================================
; Hotkeys
;=============================================

;Hotkey is only only active if active window is Mintty with title that contains julia.exe path.
#If WinActive("julia.exe")

	^c::	;^=ctrl.  The follow block will run when Ctrl+C is pressed (given the above, only if Mintty is active)

		;Continue if we have process ID for Julia and sufficient time has elapsed since last activation.
		if (A_TimeSincePriorHotkey > GOD_MODE_OFF_DELAY || A_TimeSincePriorHotkey == -1) 
		&& (juliaPID := findJuliaPID(minttyPID := WinGetPID("A"))){ 
		
			;Obtain process handle of Mintty.exe associated with Julia
			pHandle := DllCall("OpenProcess", "UInt", 0x0010, "Char", 0, "UInt", minttyPID, "Ptr")
			
			;Read Mintty version from memory.  Continue if we have the current version.
			buffer := BufferAlloc(31)
			DllCall("ReadProcessMemory", "UInt", pHandle, "Ptr", MINTTY_VERSION, "Ptr", buffer.Ptr, "UInt", buffer.Size, "Ptr", 0)
			minttyVersion := StrGet(buffer, buffer.Size, "UTF-8")
			if minttyVersion == "mintty 2.9.5 (x86_64-pc-cygwin)" {
			
				;Read Julia Execution State.  If Julia is busy (ie, can be interrupted), continue.
				buffer := BufferAlloc(1)
				DllCall("ReadProcessMemory", "UInt", pHandle, "Ptr", JULIA_EXE_STATE, "Ptr", buffer.Ptr, "UInt", buffer.Size, "Ptr", 0)
				juliaReady := NumGet(buffer, "UChar")
				if !juliaReady {	; busy = 0, idle/ready = 1
					
					;The following technique is taken shamelessly from Stack Overflow
					;https://stackoverflow.com/questions/813086/can-i-send-a-ctrl-c-sigint-to-an-application-on-windows
					DllCall("AttachConsole", "UInt", juliaPID)
					DllCall("SetConsoleCtrlHandler", "Ptr", 0, "Int", true)		;power overwhelming (immune to Ctrl+C)
					DllCall("GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0)	;SIGINT!!! (Ctrl+C)
					DllCall("FreeConsole")										;Detach so we don't kill ourselves.
					Sleep GOD_MODE_OFF_DELAY
					DllCall("SetConsoleCtrlHandler", "Ptr", 0, "Int", false)	;This script is no longer immune to Ctrl+C
				}
			}
			
			;Done with memory reading.  Close process handle.
			DllCall("CloseHandle", "Ptr", pHandle)
		}
	return
#If



;=============================================
; Debugging
;=============================================

/*	This Block is commented out.  Use it to populate a ListView of all processes for debugging.
;https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process
Gui := GuiCreate(, "Process List")
LV := Gui.Add("ListView", "x2 y0 w1200 h500", "Process Name|Command Line|PID|Parent PID|Parent Name")
for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
	LV.Add("", process.Name, process.CommandLine, process.processId, process.ParentProcessId, WinGetProcessName("ahk_pid" process.ParentProcessId))
Gui.Show 
*/