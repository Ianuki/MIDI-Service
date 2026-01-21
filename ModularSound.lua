--!strict

local Notes = {
	[0] = "C",
	[1] = "C#",
	[2] = "D",
	[3] = "D#",
	[4] = "E",
	[5] = "F",
	[6] = "F#",
	[7] = "G",
	[8] = "G#",
	[9] = "A",
	[10] = "A#",
	[11] = "B"
}

export type ModularSound = {
	Sound: Sound,
	Pitch: number,
	Volume: number,
	Octave: number,
	Semitone: number,
	Async: boolean,
	Playing: boolean,
	
	new: (Sound: Sound, Pitch: number?, Volume: number?, Semitone: number?, Octave: number?) -> (),
	
	SetAsync: (self: ModularSound, NewAsync: boolean) -> (),
	SetPitch: (self: ModularSound, NewPitch: number) -> (),
	SetVolume: (self: ModularSound, NewVolume: number) -> (),
	SetOctave: (self: ModularSound, NewOctave: number) -> (),
	SetSemitone: (self: ModularSound, NewSemitone: number) -> (),
	SetNoteDataFromNumber: (self: ModularSound, NoteNumber: number) -> (),
	FormatNote: (self: ModularSound, Octave: boolean) -> string,
	SoundDataToPlaybackSpeed: (self: ModularSound, ToneValue : number) -> number,
	Play: (self: ModularSound) -> (),
	Stop: (self: ModularSound) -> (),
	Destroy: (self: ModularSound) -> ()
}

local ModularSound = {}
ModularSound.__index = ModularSound

function ModularSound.new(Sound: Sound, Pitch: number?, Volume: number?, Semitone: number?, Octave: number?): ModularSound
 	local self = setmetatable({} :: any, ModularSound) :: ModularSound
	self.Sound = Sound
	self.Pitch = Pitch or 1
	self.Volume = Volume or Sound.Volume
	self.Playing = false
	self.Octave = Octave or 5
	self.Async = true
	self.Semitone = Semitone or 0 -- C
	
	return self
end

function ModularSound:SetAsync(NewAsync: boolean)
	self.Async = NewAsync
end

function ModularSound:SetPitch(NewPitch: number)
	self.Pitch = NewPitch
end

function ModularSound:SetVolume(NewVolume: number)
	self.Volume = NewVolume
end

function ModularSound:SetOctave(NewOctave: number)
	self.Octave = NewOctave
end

function ModularSound:SetSemitone(NewSemitone: number)
	self.Semitone = NewSemitone
end

function ModularSound:SoundDataToPlaybackSpeed(Semitone: number): number
	return 2 ^ (((self.Octave :: number - 4) * 12 + Semitone) / 12) * self.Pitch
end

function ModularSound:FormatNote(Octave: boolean): string
	if Octave == nil then
		Octave = true
	end
	
	if Octave then
		return string.format("%s%d", Notes[self.Semitone], self.Octave)
	else
		return Notes[self.Semitone]
	end
end

--[[ For MIDI ]]
function ModularSound:SetNoteDataFromNumber(NoteNumber: number)
	local Seminote = NoteNumber % 12
	local Octave = math.floor(NoteNumber / 12) - 1
	
	self:SetSemitone(Seminote)
	self:SetOctave(Octave)
end

function ModularSound:Play()
	local PlaybackSpeed = self:SoundDataToPlaybackSpeed(self.Semitone)
	self.Sound.PlaybackSpeed = PlaybackSpeed
	self.Sound.Volume = self.Volume
	self.Playing = true
	
	local ActiveSound: Sound = self.Sound
	local Async = self.Async
	
	if self.Async then
		local SoundClone = self.Sound:Clone()
		SoundClone.Parent = self.Sound.Parent
		ActiveSound = SoundClone	
	end
	
	ActiveSound:Play()
	ActiveSound.Ended:Once(function()
		self.Playing = false
		
		if Async then
			ActiveSound:Destroy()
		end
	end)
end

function ModularSound:Stop()
	self.Sound:Stop()
end

function ModularSound:Destroy()
	self.Sound:Destroy()
	table.clear(self)
	self = nil :: any
end

return ModularSound
