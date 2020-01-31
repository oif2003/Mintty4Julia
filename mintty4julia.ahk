#SingleInstance Force

;=============================================
; Auto-execute Section
;=============================================
;Memory offset constants
MINTTY_VERSION := 0x100462310
JULIA_STATE := 0x100497FA0

cygwin64bin  := A_ScriptDir "\CygwinPortable\App\Runtime\Cygwin\bin"
juliaExePath := StrReplace(A_AppData, "Roaming") "Local\Julia-1.3.1\bin\julia.exe"	

;rename user directory otherwise windows emojis will not load										
Loop Files, A_ScriptDir "\CygwinPortable\App\Runtime\Cygwin\home\*", "D"						
	folderpath := A_LoopFileFullPath															 
DirMove(folderpath, A_ScriptDir "\CygwinPortable\App\Runtime\Cygwin\home\" A_UserName, "R")

;Set path to Cygwin's bin folder for Mintty and start Julia using VBScript. 
shell := ComObjCreate("WScript.Shell")
exec := shell.Exec(A_ComSpec)
exec.StdIn.WriteLine("set PATH=%PATH%;" cygwin64bin "`n" "mintty.exe " juliaExePath "`nexit")



;=============================================
; Function Definitons
;=============================================
findJuliaPID() {
	juliaPID := 0
	juliaProcesses := Array()
	minttyProcesses := Array()
	
	/*	This Block is commented out.  Use it to populate a ListView of all processes for debugging.
	;https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process
	Gui := GuiCreate(, "Process List")
	LV := Gui.Add("ListView", "x2 y0 w1200 h500", "Process Name|Command Line|PID|Parent PID|Parent Name")
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
		LV.Add("", process.Name, process.CommandLine, process.processId, process.ParentProcessId, WinGetProcessName("ahk_pid" process.ParentProcessId))
	Gui.Show 
	*/

	;Gather information on all processes that are named "julia.exe" and "mintty.exe"
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process")
		Switch process.Name {
			Case "julia.exe":
				juliaProcesses.Push({PID:process.ProcessId, ParentPID:process.ParentProcessId, CommandLine:process.CommandLine})
			Case "mintty.exe": 
				minttyProcesses.Push({PID:process.ProcessId, ParentPID:process.ParentProcessId, CommandLine:process.CommandLine})
		}

	;Find out which "julia.exe" is a child of a "mintty.exe".  This is our target for sending SIGINT.  Return its process ID.
	if juliaProcesses.Length && minttyProcesses.Length
		for _, j in juliaProcesses
			if InStr(j.CommandLine, "1.3.1")
				for _, m in minttyProcesses
					if j.ParentPID == m.PID
						juliaPID := j.PID

	return juliaPID
}

;Find the process ID of Mintty window running Julia REPL.
findMinttyPID() => WinGetPID("\Julia-1.3.1\bin\julia.exe")



;=============================================
; Hotkeys
;=============================================
;Hotkey is only only active if active window is Mintty with title that contains julia.exe path.
;This also ensures the loaded Julia version is 1.3.1
#If WinActive("\Julia-1.3.1\bin\julia.exe")
	
	^c::	;^=ctrl.  The follow block will run when Ctrl+C is pressed (given the above, only if Mintty is active)
	
		;Only continue we have process ID's for Julia and Mintty
		if (juliaPID := findJuliaPID())
		&& (minttyPID := findMinttyPID()) { 
		
			;Obtain process handle of Mintty.exe that is associated with the Julia window
			pHandle := DllCall("OpenProcess", "UInt", 0x0010, "Char", 0, "UInt", minttyPID, "Ptr")
			
			;Read Mintty version from memory.  Continue if we have the current version.
			buffer := BufferAlloc(31)
			DllCall("ReadProcessMemory", "UInt", pHandle, "Ptr", MINTTY_VERSION, "Ptr", buffer.Ptr, "UInt", buffer.Size, "Ptr", 0)
			minttyVersion := StrGet(buffer, buffer.Size, "UTF-8")
			if minttyVersion == "mintty 2.9.5 (x86_64-pc-cygwin)" {
			
				;Read Julia Execution State.  If Julia is busy (ie, can be interrupted), continue.
				buffer := BufferAlloc(1)
				DllCall("ReadProcessMemory", "UInt", pHandle, "Ptr", JULIA_STATE, "Ptr", buffer.Ptr, "UInt", buffer.Size, "Ptr", 0)
				juliaReady := NumGet(buffer, "UChar")
				if !juliaReady {	; busy = 0, idle/ready = 1
					
					;The following technique is taken shamelessly from Stack Overflow
					;https://stackoverflow.com/questions/813086/can-i-send-a-ctrl-c-sigint-to-an-application-on-windows
					DllCall("AttachConsole", "UInt", juliaPID)
					DllCall("SetConsoleCtrlHandler", "Ptr", 0, "Int", true)
					DllCall("GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0)
					DllCall("FreeConsole")
					Sleep 2000
					DllCall("SetConsoleCtrlHandler", "Ptr", 0, "Int", false)
				}
			}
			
			;Done with memory reading.  Close process handle.
			DllCall("CloseHandle", "Ptr", pHandle)
		}
	return
#If

