--!strict

local HttpService = game:GetService("HttpService")

local function BytesToNumber(B1: number, B2: number, B3: number, B4: number): number
	return B1 * 256^3 + B2 * 256^2 + B3 * 256 + B4
end

local function BytesToShort(B1: number, B2: number): number
	return B1 * 256 + B2
end

local function ReadVariableLength(Bytes: {}, Start: number): (number, number)
	local Value = 0
	local i = Start
	
	while true do
		local Byte = Bytes[i]
		
		Value = (Value * 128) + (Byte % 128)
		i = i + 1
		
		if Byte < 128 then
			break
		end
	end
	
	return Value, i
end

local MidiParser = {}

export type HeaderData = {
	Format: number, 
	Tracks: number,
	Division: number
}

export type NoteData = {
	Note: number,
	Time: number,
	Velocity: number
}

export type TrackData = {
	NoteData
}

function MidiParser.GetRaw(URL: string)
	local Success, Result = pcall(function()
		return HttpService:GetAsync(URL, true)
	end)
	
	if Success then
		return Result
	else
		return ""
	end
end

function MidiParser.GetBytes(Raw: string)
	local Bytes = {}
	
	for i = 1, #Raw do
		Bytes[i] = string.byte(Raw, i)
	end
	
	return Bytes
end

function MidiParser.ParseHeader(Bytes: {}): HeaderData
	local HeaderLength = BytesToNumber(Bytes[5], Bytes[6], Bytes[7], Bytes[8])
	local Format = BytesToShort(Bytes[9], Bytes[10])
	local Tracks = BytesToShort(Bytes[11], Bytes[12])
	local Division = BytesToShort(Bytes[13], Bytes[14])

	return {
		["Format"] = Format,
		["Tracks"] = Tracks,
		["Division"] = Division
	} :: HeaderData
end

function MidiParser.ParseTrack(Bytes: {}, Division: number): TrackData
	local i = 1
	local Time = 0
	local Notes = {}
	local LastStatus = nil

	while i <= #Bytes do
		local Delta, NextIndex = ReadVariableLength(Bytes, i)
		Time = Time + Delta
		i = NextIndex

		local Status = Bytes[i]
		
		if Status < 0x80 then
			Status = LastStatus
			i = i - 1
		else
			i = i + 1
		end
		
		LastStatus = Status

		local EventType = math.floor(Status / 16) * 16 
		local Channel = Status % 16   

		if EventType == 0x90 then
			local Note = Bytes[i]
			local Velocity = Bytes[i + 1]
			
			i = i + 2
			
			if Velocity > 0 then
				table.insert(Notes, {["Note"] = Note, ["Time"] = Time / Division, ["Velocity"] = Velocity} :: NoteData)
			end
			
		elseif EventType == 0x80 then 
			i = i + 2
		else
			local DataLength = 0
			if EventType == 0xC0 or EventType == 0xD0 then
				DataLength = 1
			else
				DataLength = 2
			end
			i = i + DataLength
		end
	end

	return Notes
end

function MidiParser.Parse(Raw: string): {}
	local Bytes = MidiParser.GetBytes(Raw)
	local Header: HeaderData = MidiParser.ParseHeader(Bytes)
	local TracksData = {}
	local i = 15

	for t = 1, Header.Tracks do
		if Bytes[i] ~= 77 or Bytes[i+1] ~= 84 or Bytes[i+2] ~= 114 or Bytes[i+3] ~= 107 then
			warn("Wrong file signature. Expected MTrk")
			break
		end
		
		local TrackLength = BytesToNumber(Bytes[i+4], Bytes[i+5], Bytes[i+6], Bytes[i+7])
		local TrackBytes = {}
		
		for j = 1, TrackLength do
			TrackBytes[j] = Bytes[i + 7 + j]
		end
		
		local TrackNotes = MidiParser.ParseTrack(TrackBytes, Header.Division)
		
		table.insert(TracksData, TrackNotes)
		
		i = i + 8 + TrackLength
	end

	return TracksData
end

return MidiParser
