class Mailslot
{
	__New(name:="", options:="r0")
	{
		if (name == "")
			name := A_ScriptName
		
		options := Trim(options, " `t`r`n")
		if (options ~= "^[Rr]\d*?$")
			return new this.base.Server(name, LTrim(options, "r"), SubStr(options, 1, 1) == "R")
		else if (options ~= "i)^w(\.|\*|[^\r\n]+)?$")
			return new this.base.Client(name, SubStr(options, 2))
		else
			return
	}

	class Server
	{
		__New(name, limit:="0", inherit_handle:=0)
		{
			filename := "\\.\mailslot\" . name
			hSlot := DllCall("CreateMailslot", "Str", filename, "UInt", Round(limit), "UInt", 0, "Ptr", 0)
			if (hSlot == -1) ;// INVALID_HANDLE_VALUE
				return false ;// throw Exception() ??

			if inherit_handle
				DllCall("SetHandleInformation", "Ptr", hSlot, "UInt", 1, "UInt", 1)
			
			this.__Handle := hSlot
			this.Name     := name
			this.Filename := filename
		}

		__Delete()
		{
			DllCall("CloseHandle", "Ptr", this.__Handle)
		}

		Dequeue(wait:=0, encoding:="CP0")
		{
			if read := this.FRead(buf, this._GetInfo("Size"), wait)
			{
				enc := RTrim(encoding, "-RAW")
				length := read // ((enc = "UTF-16" || enc = "CP1200") ? 2 : 1)
				return StrGet(&buf, length, enc)
			}
		}

		FRead(ByRef buf, bytes:=-1, wait:=0)
		{
			hSlot := this.__Handle
			VarSetCapacity(tmp_buf, size := this._GetInfo("Size"))
			if (wait != this.Timeout)
				this.Timeout := wait
			if res := DllCall("ReadFile", "Ptr", hSlot, "Ptr", &tmp_buf, "UInt", size, "UIntP", read := 0, "Ptr", 0)
			{
				if (bytes < 0 || bytes > read)
					bytes := read
				if IsByRef(buf)
					VarSetCapacity(buf, bytes), pBuf := &buf
				else
					pBuf := buf + 0
				DllCall("RtlMoveMemory", "Ptr", pBuf, "Ptr", &tmp_buf, "UPtr", bytes)
				return read
			}
		}

		MsgCount {
			get {
				if ((count := this._GetInfo("count")) != "") ;// msg_count
					return count
			}
			set {
				return
			}
		}

		Timeout {
			get {
				return this._GetInfo("timeout") ;// read_timeout
			}
			set {
				hSlot := this.__Handle
				prev := this._GetInfo("timeout")
				return DllCall("SetMailslotInfo", "Ptr", hSlot, "UInt", Round(value)) ? prev : ""
			}
		}

		_GetInfo(which) ;// which := [ limit(write), size(msg size), count, timeout ]
		{
			; if !(which := SubStr(which, which ~= "i)^(write_)?\Klimit|(msg_)?\K(size|count)|(read_)?\Ktimeout$"))
			; 	return
			hSlot := this.__Handle
			if DllCall("GetMailslotInfo", "Ptr", hSlot, "UIntP", limit, "UIntP", size, "UIntP", count, "UIntP", timeout)
			{
				; though unreliable, InStr() should be faster than the commented
				; RegEx above. I reckon that most usage of this method will be
				; inside loops, esp. for 'msg_count' and 'msg_size'.
				if pos := InStr(which, "_")
					which := SubStr(which, pos + 1)
				return (%which%) ;// '()' for v1.1+
			}
		}
	}

	class Client
	{
		__New(name, machine:=".")
		{
			if (machine == "")
				machine := "."
			
			this.Name     := name
			this.Machine  := machine
			this.Filename := "\\" . machine . "\mailslot\" . name
		}

		Enqueue(data, encoding:="CP0")
		{
			if fSlot := FileOpen(this.Filename, "w")
			{
				fSlot.Encoding := encoding
				return fSlot.Write(data)
			}
		}

		FWrite(ByRef buf, bytes)
		{
			if fSlot := FileOpen(this.Filename, "w")
				return fSlot.RawWrite(buf, bytes)
		}
	}
}