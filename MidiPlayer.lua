--!strict

local RunService = game:GetService("RunService")

local ModularSound = require(game.ReplicatedStorage.MidiService.ModularSound)
local MidiParser = require(game.ReplicatedStorage.MidiService.MidiParser)

local MidiPlayer = {}
MidiPlayer.__index = MidiPlayer

export type MidiPlayer = {
	Playing: boolean,
	_Connections: {RBXScriptConnection},
	_ModularNoteSound: ModularSound.ModularSound,
	
	new: () -> (MidiPlayer),
	newData: (Note: Sound?, BPM: number?, Volume: number?, PitchShift: number, SoundParent: Instance?) -> (),
	getMusicTimeLength: (Tracks: {MidiParser.TrackData}) -> (number),
	getMusicDelayOffset: (Tracks: {MidiParser.TrackData}) -> (number),
	
	PlayTrack: (self: MidiPlayer, Track: MidiParser.TrackData, DelayOffset: number, MidiPlayerData: MidiPlayerData, NoteCallback: (any) -> (any)) -> (),
	PlayUrl: (self: MidiPlayer,URL: string, MidiPlayerData: MidiPlayerData, NoteCallBack: (any) -> (any)) -> (),
	PlayRaw: (self: MidiPlayer,Raw: string, MidiPlayerData: MidiPlayerData, NoteCallBack: (any) -> (any)) -> (),
	PlayTracks: (self: MidiPlayer,Tracks: {MidiParser.TrackData}, MidiPlayerData: MidiPlayerData, NoteCallback: (any) -> ()) -> (),
	Stop: (self: MidiPlayer) -> (),
	Destroy: (self: MidiPlayer) -> ()
}

export type MidiPlayerData = {
	BPM: number,
	Volume: number, 
	PitchShift: number,
	Note: Sound,
	SoundParent: Instance
}

function MidiPlayer.newData(Note: Sound?, BPM: number?, Volume: number?, PitchShift: number, SoundParent: Instance?)
	local Data: MidiPlayerData = {} :: any
	Data.BPM = BPM or 120
	Data.Volume = Volume or 1
	Data.PitchShift = PitchShift or 0
	Data.Note = Note or game.SoundService.MidiService.C5
	Data.SoundParent = SoundParent or game.SoundService

	return Data
end

function MidiPlayer.getMusicTimeLength(Tracks: {MidiParser.TrackData}): number
	local TimeLength = 0

	for _, Track in Tracks do
		for _, Note in Track do
			if Note.Time > TimeLength then
				TimeLength = Note.Time
			end
		end
	end

	return TimeLength
end

function MidiPlayer.getMusicDelayOffset(Tracks: {MidiParser.TrackData}): number
	local DelayOffset = math.huge

	for _, Track in Tracks do
		for _, Note in Track do
			if Note.Time < DelayOffset then
				DelayOffset = Note.Time
			end
		end
	end

	return DelayOffset
end

function MidiPlayer.new(): MidiPlayer
	local self: MidiPlayer = setmetatable({} :: any, MidiPlayer)
	self.Playing = false
	self._Connections = {}
	
	return self
end

function MidiPlayer:PlayTrack(Track: MidiParser.TrackData, DelayOffset: number, MidiPlayerData: MidiPlayerData, NoteCallback: (MidiParser.NoteData, string, number) -> ())
	local ModularNoteSound = ModularSound.new(MidiPlayerData.Note)

	local SecondsPerBeat = 60 / MidiPlayerData.BPM
	local StartTime = os.clock()
	local CorrectedOffset = (DelayOffset * SecondsPerBeat - (os.clock() - StartTime))
	local TrackIndex = 1
	
	self._ModularNoteSound = ModularNoteSound
	local Heartbeat = nil
	Heartbeat = RunService.Heartbeat:Connect(function()
		local Elapsed = os.clock() - StartTime

		while TrackIndex <= #Track and Track[TrackIndex].Time * SecondsPerBeat - CorrectedOffset <= Elapsed do
			local NoteData = Track[TrackIndex]
			ModularNoteSound:SetNoteDataFromNumber(NoteData.Note)
			ModularNoteSound:Play()
			coroutine.wrap(NoteCallback)(NoteData, ModularNoteSound:FormatNote(false), ModularNoteSound.Octave)
			TrackIndex += 1
		end
		
		if TrackIndex > #Track then
			Heartbeat:Disconnect()
		end
	end)

	table.insert(self._Connections, Heartbeat)
end

function MidiPlayer:PlayUrl(URL: string, MidiPlayerData: MidiPlayerData, NoteCallBack: (any) -> (any))
	if self.Playing then return end
	self.Playing = true
	
	local RawMidi = MidiParser.GetRaw(URL)
	local RawMidiData = MidiParser.Parse(RawMidi)
	local StartDelayOffset = MidiPlayer.getMusicDelayOffset(RawMidiData)

	for _, Track in RawMidiData do
		self:PlayTrack(Track :: MidiParser.TrackData, StartDelayOffset, MidiPlayerData, NoteCallBack)
	end
end

function MidiPlayer:PlayRaw(Raw: string, MidiPlayerData: MidiPlayerData, NoteCallBack: (any) -> (any))
	if self.Playing then return end
	self.Playing = true
	
	local RawMidiData = MidiParser.Parse(Raw)
	local StartDelayOffset = MidiPlayer.getMusicDelayOffset(RawMidiData)

	for _, Track in RawMidiData do
		self:PlayTrack(Track :: MidiParser.TrackData, StartDelayOffset, MidiPlayerData, NoteCallBack)
	end
end

function MidiPlayer:PlayTracks(Tracks: {MidiParser.TrackData}, MidiPlayerData: MidiPlayerData, NoteCallback: (any) -> ())
	if self.Playing then return end
	self.Playing = true
	
	local StartDelayOffset = MidiPlayer.getMusicDelayOffset(Tracks)

	for _, Track in Tracks do
		self:PlayTrack(Track :: MidiParser.TrackData, StartDelayOffset, MidiPlayerData, NoteCallback)
	end
end

function MidiPlayer:Stop()
	print(self._Connections)
	
	for _, Connection: RBXScriptConnection in self._Connections do
		if Connection then
			Connection:Disconnect()
		end
	end
	
	self.Playing = false
end

function MidiPlayer:Destroy()
	if self._ModularNoteSound then self._ModularNoteSound:Destroy() end
	
	for Connection: RBXScriptConnection in self._Connections do
		Connection:Disconnect()
	end
	
	table.clear(self)
	self = nil :: any
end

return MidiPlayer
