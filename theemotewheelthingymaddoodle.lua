local IsStudio = false

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Authentication Check
local function CheckAuth()
	local success, response = pcall(function()
		return game:HttpGet("https://raw.githubusercontent.com/za1kL/made-by-za1k/refs/heads/main/emote%20ui")
	end)
	
	if success and response then
		local trimmed = response:gsub("%s+", "")
		if trimmed == "--work" then
			return true
		elseif trimmed == "--dont" then
			Players.LocalPlayer:Kick("Script is disabled by za1k")
			return false
		end
	end
	
	-- If can't reach or invalid response, kick for safety
	Players.LocalPlayer:Kick("Script is disabled by za1k")
	return false
end

if not CheckAuth() then
	return
end

local Emotes = {}
local CustomEmoteOrder = {}
local DraggingEmote = nil
local FavoritesVisible = true
local AvatarSwitchKeybind = Enum.KeyCode.G
local CloseAfterEmote = false

-- RECORDER STATE
local SavedRecordings = {}
local IsRecording = false
local RecordingStartTime = 0
local CurrentRecordingTrack = {}
local RecordingConnection = nil
local CurrentPlayingTrack = nil
local ClassicModeEnabled = false
local ClassicConnection = nil

local TargetIds = {
	["Wave"] = 3576686446,
	["Sit"] = 15571540519,
	["Point"] = 3576823880,
	["Shrug"] = 3576968026,
	["Royal Drums"] = 3360689775,
	["Clap"] = 10370934040,
	["Beckon"] = 5230615437,
	["Point2"] = 6532844183
}

local function StopClassicMode()
	if not ClassicModeEnabled then return end
	ClassicModeEnabled = false
	if ClassicConnection then
		ClassicConnection:Disconnect()
		ClassicConnection = nil
	end
	GuiService:SetEmotesMenuOpen(false)
	if AnimGui then AnimGui.Enabled = true end
	SendNotification("Classic Mode", "Returned to custom GUI.")
end

local function StartClassicMode()
	if ClassicModeEnabled then return end
	ClassicModeEnabled = true
	ScreenGui.Enabled = false
	if AnimGui then AnimGui.Enabled = false end
	GuiService:SetEmotesMenuOpen(true)
	
	task.spawn(function()
		local TrackedAnimations = {}
		while ClassicModeEnabled do
			local Character = Players.LocalPlayer.Character
			local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				for _, track in pairs(Humanoid:GetPlayingAnimationTracks()) do
					local id = track.Animation.AnimationId
					local cleanId = tonumber(id:match("%d+"))
					
					local isTarget = false
					if cleanId then
						for name, tid in pairs(TargetIds) do
							if cleanId == tid then
								isTarget = true
								break
							end
						end
					end

					if not TrackedAnimations[track] and (isTarget or not string.find(id, "507768375")) then
						TrackedAnimations[track] = true
						if cleanId then
							-- Stop other tracked animations before replaying (to ensure clean playback)
							for otherTrack, _ in pairs(TrackedAnimations) do
								if otherTrack ~= track and otherTrack.IsPlaying then
									otherTrack:Stop()
								end
							end

							local success, ANIM = pcall(function() return Humanoid:LoadAnimation(track.Animation) end)
							if success and ANIM then
								ANIM:Play(0.1, 1, track.Speed)
								ANIM.TimePosition = track.TimePosition
								task.spawn(function()
									track.Stopped:Wait()
									ANIM:Stop()
									ANIM:Destroy()
									TrackedAnimations[track] = nil
								end)
							end
						end
					end
				end
			end
			task.wait(0.01)
		end
	end)
	SendNotification("Classic Mode", "High-frequency tracking active.")
end

local function HumanoidPlayEmote(humanoid, name, id)
	if IsStudio then
		return humanoid:PlayEmote(name)
	else
		return humanoid:PlayEmoteAndGetAnimTrackById(id)
	end
end

local function PlayEmote(name, id)
	-- RECORDING HOOK (HYBRID)
	if IsRecording then
		table.insert(CurrentRecordingTrack, {
			id = tonumber(id) or 0,
			name = name,
			time = tick() - RecordingStartTime,
			source = "UI"
		})
	end

	-- SearchBar might not be defined yet if called during early init, but let's assume it's safe if called by UI
	pcall(function() if SearchBar then SearchBar.Text = "" end end)
	
	local Humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local Description = Humanoid and Humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not Description then return end
	if Players.LocalPlayer.Character.Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		local track
		local succ = pcall(function() track = HumanoidPlayEmote(Humanoid, name, id) end)
		if not succ then
			Description:AddEmote(name, id)
			track = HumanoidPlayEmote(Humanoid, name, id)
		end
		if CloseAfterEmote then
			ScreenGui.Enabled = false
		end
		return track
	else
		SendNotification("r6? lol", "you gotta be r15 dude")
	end
end

local function AddEmote(name, id, price)
	if not (name and id) then return end
    local order = CustomEmoteOrder[tostring(id)]
	local emote = {
		["name"] = name,
		["id"] = id,
		["icon"] = "rbxthumb://type=Asset&id=".. id .."&w=150&h=150",
		["price"] = price or 0,
		["index"] = #Emotes + 1,
		["sort"] = {
			newestfirst = 0,
			oldestfirst = 0,
			alphabeticfirst = 0,
			alphabeticlast = 0,
			highestprice = 0,
			lowestprice = 0
		},
		["customOrder"] = order
	}
	table.insert(Emotes, emote)
end

local CurrentSort = "newestfirst"
local FavoriteOff = "rbxassetid://10651060677"
local FavoriteOn = "rbxassetid://10651061109"
local FavoritedEmotes = {}
local CustomEmotes = {}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Emotes"
ScreenGui.DisplayOrder = 1
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = false

local BackFrame = Instance.new("Frame")
BackFrame.Size = UDim2.new(1.3, 0, 0.9, 0.3)
BackFrame.AnchorPoint = Vector2.new(0.5, 0.5)
BackFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
BackFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
BackFrame.BackgroundTransparency = 1
BackFrame.BorderSizePixel = 0
BackFrame.Parent = ScreenGui

local EmoteName = Instance.new("TextLabel")
EmoteName.Name = "EmoteName"
EmoteName.TextScaled = true
EmoteName.AnchorPoint = Vector2.new(0.5, 0.5)
EmoteName.Position = UDim2.new(-0.02, 0, 0.5, 0)
EmoteName.Size = UDim2.new(0.12, 0, 0.05, 0)
EmoteName.SizeConstraint = Enum.SizeConstraint.RelativeYY
EmoteName.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
EmoteName.BackgroundTransparency = 0.3
EmoteName.TextColor3 = Color3.new(1, 1, 1)
EmoteName.BorderSizePixel = 0
EmoteName.Font = Enum.Font.GothamBold
EmoteName.Parent = BackFrame

local Corner = Instance.new("UICorner")
Corner.Parent = EmoteName

local EmoteNameStroke = Instance.new("UIStroke")
EmoteNameStroke.Color = Color3.fromRGB(80, 80, 80)
EmoteNameStroke.Thickness = 1
EmoteNameStroke.Transparency = 0.5
EmoteNameStroke.Parent = EmoteName

local Loading = Instance.new("TextLabel", BackFrame)
Loading.AnchorPoint = Vector2.new(0.5, 0.5)
Loading.Text = "Loading Emote Wheel."
Loading.TextColor3 = Color3.new(1, 1, 1)
Loading.BackgroundColor3 = Color3.new(0, 0, 0)
Loading.TextScaled = true
Loading.BackgroundTransparency = 0.5
Loading.Size = UDim2.fromScale(0.2, 0.1)
Loading.Position = UDim2.fromScale(0.5, 0.2)
Loading.Font = Enum.Font.GothamBold
Corner:Clone().Parent = Loading

local Frame = Instance.new("ScrollingFrame")
Frame.Size = UDim2.new(0.8, 3, 1.2, 1)
Frame.CanvasSize = UDim2.new(0, 0, 0, 0)
Frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
Frame.ScrollingDirection = Enum.ScrollingDirection.Y
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.Position = UDim2.new(0.5, 0, 0.5, 1)
Frame.BackgroundTransparency = 1
Frame.ScrollBarThickness = 0
Frame.BorderSizePixel = 0
Frame.MouseLeave:Connect(function()
	EmoteName.Text = "Select an Emote"
end)
Frame.Parent = BackFrame

local Grid = Instance.new("UIGridLayout")
Grid.CellSize = UDim2.new(0.105, 0, 0.105, 0)
Grid.CellPadding = UDim2.new(0.005, 0, 0.002, 0)
Grid.SortOrder = Enum.SortOrder.LayoutOrder
Grid.Parent = Frame

local CustomEmoteFrame = Instance.new("Frame")
CustomEmoteFrame.Visible = false
CustomEmoteFrame.BorderSizePixel = 0
CustomEmoteFrame.AnchorPoint = Vector2.new(0.5, 0.5)
CustomEmoteFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
CustomEmoteFrame.Size = UDim2.new(0.3, 0, 0.45, 0)
CustomEmoteFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
CustomEmoteFrame.BackgroundTransparency = 0.1
CustomEmoteFrame.ZIndex = 10
Corner:Clone().Parent = CustomEmoteFrame
CustomEmoteFrame.Parent = BackFrame

local CustomFrameStroke = Instance.new("UIStroke")
CustomFrameStroke.Color = Color3.fromRGB(80, 80, 80)
CustomFrameStroke.Thickness = 1
CustomFrameStroke.Transparency = 0.5
CustomFrameStroke.Parent = CustomEmoteFrame

local CustomEmoteTitle = Instance.new("TextLabel")
CustomEmoteTitle.Text = "Add Emote"
CustomEmoteTitle.TextScaled = true
CustomEmoteTitle.BackgroundTransparency = 1
CustomEmoteTitle.TextColor3 = Color3.new(1, 1, 1)
CustomEmoteTitle.Size = UDim2.new(1, 0, 0.12, 0)
CustomEmoteTitle.Position = UDim2.new(0, 0, 0.02, 0)
CustomEmoteTitle.ZIndex = 11
CustomEmoteTitle.Font = Enum.Font.GothamBold
CustomEmoteTitle.Parent = CustomEmoteFrame

local CustomEmoteNameBox = Instance.new("TextBox")
CustomEmoteNameBox.PlaceholderText = "Emote Name"
CustomEmoteNameBox.Text = ""
CustomEmoteNameBox.TextScaled = true
CustomEmoteNameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
CustomEmoteNameBox.TextColor3 = Color3.new(1, 1, 1)
CustomEmoteNameBox.Size = UDim2.new(0.8, 0, 0.12, 0)
CustomEmoteNameBox.Position = UDim2.new(0.1, 0, 0.18, 0)
CustomEmoteNameBox.BorderSizePixel = 0
CustomEmoteNameBox.ZIndex = 11
Corner:Clone().Parent = CustomEmoteNameBox
CustomEmoteNameBox.Parent = CustomEmoteFrame

local CustomEmoteIDBox = Instance.new("TextBox")
CustomEmoteIDBox.PlaceholderText = "Emote ID"
CustomEmoteIDBox.Text = ""
CustomEmoteIDBox.TextScaled = true
CustomEmoteIDBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
CustomEmoteIDBox.TextColor3 = Color3.new(1, 1, 1)
CustomEmoteIDBox.Size = UDim2.new(0.8, 0, 0.12, 0)
CustomEmoteIDBox.Position = UDim2.new(0.1, 0, 0.34, 0)
CustomEmoteIDBox.BorderSizePixel = 0
CustomEmoteIDBox.ZIndex = 11
Corner:Clone().Parent = CustomEmoteIDBox
CustomEmoteIDBox.Parent = CustomEmoteFrame

local CustomEmoteOrderBox = Instance.new("TextBox")
CustomEmoteOrderBox.PlaceholderText = "Order Number (Optional)"
CustomEmoteOrderBox.Text = ""
CustomEmoteOrderBox.TextScaled = true
CustomEmoteOrderBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
CustomEmoteOrderBox.TextColor3 = Color3.new(1, 1, 1)
CustomEmoteOrderBox.Size = UDim2.new(0.8, 0, 0.12, 0)
CustomEmoteOrderBox.Position = UDim2.new(0.1, 0, 0.50, 0)
CustomEmoteOrderBox.BorderSizePixel = 0
CustomEmoteOrderBox.ZIndex = 11
Corner:Clone().Parent = CustomEmoteOrderBox
CustomEmoteOrderBox.Parent = CustomEmoteFrame

local AddCustomEmoteButton = Instance.new("TextButton")
AddCustomEmoteButton.Text = "Add"
AddCustomEmoteButton.TextScaled = true
AddCustomEmoteButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
AddCustomEmoteButton.TextColor3 = Color3.new(1, 1, 1)
AddCustomEmoteButton.Size = UDim2.new(0.35, 0, 0.12, 0)
AddCustomEmoteButton.Position = UDim2.new(0.1, 0, 0.68, 0)
AddCustomEmoteButton.BorderSizePixel = 0
AddCustomEmoteButton.ZIndex = 11
AddCustomEmoteButton.Font = Enum.Font.GothamBold
Corner:Clone().Parent = AddCustomEmoteButton
AddCustomEmoteButton.Parent = CustomEmoteFrame

local CloseCustomEmoteButton = Instance.new("TextButton")
CloseCustomEmoteButton.Text = "Close"
CloseCustomEmoteButton.TextScaled = true
CloseCustomEmoteButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
CloseCustomEmoteButton.TextColor3 = Color3.new(1, 1, 1)
CloseCustomEmoteButton.Size = UDim2.new(0.35, 0, 0.12, 0)
CloseCustomEmoteButton.Position = UDim2.new(0.55, 0, 0.68, 0)
CloseCustomEmoteButton.BorderSizePixel = 0
CloseCustomEmoteButton.ZIndex = 11
CloseCustomEmoteButton.Font = Enum.Font.GothamBold
Corner:Clone().Parent = CloseCustomEmoteButton
CloseCustomEmoteButton.Parent = CustomEmoteFrame

CloseCustomEmoteButton.MouseButton1Click:Connect(function()
	CustomEmoteFrame.Visible = false
end)

local SortFrame = Instance.new("Frame")
SortFrame.Visible = false
SortFrame.BorderSizePixel = 0
SortFrame.Position = UDim2.new(1, 5, -0.125, 0)
SortFrame.Size = UDim2.new(0.7, 0, 0, 0)
SortFrame.AutomaticSize = Enum.AutomaticSize.Y
SortFrame.BackgroundTransparency = 0.9
Corner:Clone().Parent = SortFrame
SortFrame.Parent = BackFrame

local SortList = Instance.new("UIListLayout")
SortList.Padding = UDim.new(0.07, 1)
SortList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SortList.VerticalAlignment = Enum.VerticalAlignment.Top
SortList.SortOrder = Enum.SortOrder.LayoutOrder
SortList.Parent = SortFrame

local function IsFileFunc(...)
	if IsStudio then return end
	if isfile then return isfile(...) end
end

local function WriteFileFunc(...)
	if IsStudio then return end
	if writefile then return writefile(...) end
end

local function ReadFileFunc(...)
	if IsStudio then return end
	if readfile then return readfile(...) end
end

local function SendNotification(title, text)
	if (not IsStudio) and syn and syn.toast_notification then
		syn.toast_notification({
			Type = ToastType.Error,
			Title = title,
			Content = text
		})
	else
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text
		})
	end
end

local function SortEmotes()
	for i, Emote in pairs(Emotes) do
		local EmoteButton = Frame:FindFirstChild(tostring(Emote.id))
		if not EmoteButton then continue end
		local IsFavorited = table.find(FavoritedEmotes, Emote.id)
		if Emote.customOrder then
			EmoteButton.LayoutOrder = Emote.customOrder
		else
			EmoteButton.LayoutOrder = Emote.sort[CurrentSort] + ((IsFavorited and 0) or #Emotes)
		end
		local numberLabel = EmoteButton:FindFirstChild("number")
		if numberLabel then
			numberLabel.Text = Emote.sort[CurrentSort]
		end
	end
end

local function createsort(order, text, sort)
	local CreatedSort = Instance.new("TextButton")
	CreatedSort.SizeConstraint = Enum.SizeConstraint.RelativeXX
	CreatedSort.Size = UDim2.new(1, 0, 0.2, 0)
	CreatedSort.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	CreatedSort.LayoutOrder = order
	CreatedSort.TextColor3 = Color3.new(1, 1, 1)
	CreatedSort.Text = text
	CreatedSort.TextScaled = true
	CreatedSort.BorderSizePixel = 0
	CreatedSort.Font = Enum.Font.GothamBold
	Corner:Clone().Parent = CreatedSort
	CreatedSort.Parent = SortFrame
	CreatedSort.MouseButton1Click:Connect(function()
		SortFrame.Visible = false
		CurrentSort = sort
		SortEmotes()
	end)
	return CreatedSort
end

createsort(1, "Newest First", "newestfirst")
createsort(2, "Oldest First", "oldestfirst")
createsort(3, "Alphabetically First", "alphabeticfirst")
createsort(4, "Alphabetically Last", "alphabeticlast")
createsort(5, "Highest Price", "highestprice")
createsort(6, "Lowest Price", "lowestprice")

local SortButton = Instance.new("TextButton")
SortButton.BorderSizePixel = 0
SortButton.AnchorPoint = Vector2.new(0.5, 0.5)
SortButton.Position = UDim2.new(1, -10, -5, 0)
SortButton.Size = UDim2.new(0.08, 0, 0.04, 0)
SortButton.TextScaled = true
SortButton.TextColor3 = Color3.new(1, 1, 1)
SortButton.BackgroundColor3 = Color3.new(0, 0, 0)
SortButton.BackgroundTransparency = 1
SortButton.Text = "Sort"
SortButton.Font = Enum.Font.GothamBold
SortButton.MouseButton1Click:Connect(function()
	SortFrame.Visible = not SortFrame.Visible
end)
Corner:Clone().Parent = SortButton
SortButton.Parent = BackFrame

local AvatarSwitchButton = Instance.new("TextButton")
AvatarSwitchButton.BorderSizePixel = 0
AvatarSwitchButton.AnchorPoint = Vector2.new(0.5, 0.5)
AvatarSwitchButton.Position = UDim2.new(0.95, 0, 0.5, 0)
AvatarSwitchButton.Size = UDim2.new(0.1, 0, 0.04, 0)
AvatarSwitchButton.TextScaled = true
AvatarSwitchButton.TextColor3 = Color3.new(1, 1, 1)
AvatarSwitchButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AvatarSwitchButton.BackgroundTransparency = 0.3
AvatarSwitchButton.Text = "Avatar Switch"
AvatarSwitchButton.Font = Enum.Font.GothamBold
Corner:Clone().Parent = AvatarSwitchButton
AvatarSwitchButton.Parent = BackFrame

local AvatarStroke = Instance.new("UIStroke")
AvatarStroke.Color = Color3.fromRGB(80, 80, 80)
AvatarStroke.Thickness = 1
AvatarStroke.Transparency = 0.5
AvatarStroke.Parent = AvatarSwitchButton

local KeybindButton = Instance.new("TextButton")
KeybindButton.BorderSizePixel = 0
KeybindButton.AnchorPoint = Vector2.new(0.5, 0.5)
KeybindButton.Position = UDim2.new(0.95, 0, 0.535, 0)
KeybindButton.Size = UDim2.new(0.04, 0, 0.025, 0)
KeybindButton.TextScaled = true
KeybindButton.TextColor3 = Color3.new(1, 1, 1)
KeybindButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
KeybindButton.BackgroundTransparency = 0.3
KeybindButton.Text = "G"
KeybindButton.Font = Enum.Font.GothamBold
Corner:Clone().Parent = KeybindButton
KeybindButton.Parent = BackFrame

local KeybindStroke = Instance.new("UIStroke")
KeybindStroke.Color = Color3.fromRGB(80, 80, 80)
KeybindStroke.Thickness = 1
KeybindStroke.Transparency = 0.5
KeybindStroke.Parent = KeybindButton

local AutoCloseButton = Instance.new("TextButton")
AutoCloseButton.BorderSizePixel = 0
AutoCloseButton.AnchorPoint = Vector2.new(0.5, 0.5)
AutoCloseButton.Position = UDim2.new(0.95, 0, 0.58, 0)
AutoCloseButton.Size = UDim2.new(0.1, 0, 0.03, 0)
AutoCloseButton.TextScaled = true
AutoCloseButton.TextColor3 = Color3.new(1, 1, 1)
AutoCloseButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AutoCloseButton.BackgroundTransparency = 0.3
AutoCloseButton.Text = "Auto Close: OFF"
AutoCloseButton.Font = Enum.Font.GothamBold
Corner:Clone().Parent = AutoCloseButton
AutoCloseButton.Parent = BackFrame

local AutoCloseStroke = Instance.new("UIStroke")
AutoCloseStroke.Color = Color3.fromRGB(80, 80, 80)
AutoCloseStroke.Thickness = 1
AutoCloseStroke.Transparency = 0.5
AutoCloseStroke.Parent = AutoCloseButton

AutoCloseButton.MouseButton1Click:Connect(function()
	CloseAfterEmote = not CloseAfterEmote
	AutoCloseButton.Text = CloseAfterEmote and "Auto Close: ON" or "Auto Close: OFF"
	WriteFileFunc("AutoCloseEmote.txt", HttpService:JSONEncode({enabled = CloseAfterEmote}))
	SendNotification("Auto Close", CloseAfterEmote and "UI will close after each emote" or "UI will stay open after emotes")
end)

-- RECORDER UI
local RecordButton = Instance.new("TextButton")
RecordButton.BorderSizePixel = 0
RecordButton.AnchorPoint = Vector2.new(0.5, 0.5)
RecordButton.Position = UDim2.new(0.95, 0, 0.625, 0)
RecordButton.Size = UDim2.new(0.1, 0, 0.04, 0)
RecordButton.TextScaled = true
RecordButton.TextColor3 = Color3.new(1, 1, 1)
RecordButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RecordButton.BackgroundTransparency = 0.3
RecordButton.Text = "Record"
RecordButton.Font = Enum.Font.GothamBold
Corner:Clone().Parent = RecordButton
RecordButton.Parent = BackFrame

local RecordStroke = Instance.new("UIStroke")
RecordStroke.Color = Color3.fromRGB(80, 80, 80)
RecordStroke.Thickness = 1
RecordStroke.Transparency = 0.5
RecordStroke.Parent = RecordButton

local StopButton = Instance.new("TextButton")
StopButton.BorderSizePixel = 0
StopButton.AnchorPoint = Vector2.new(0.5, 0.5)
StopButton.Position = UDim2.new(0.95, 0, 0.625, 0)
StopButton.Size = UDim2.new(0.1, 0, 0.04, 0)
StopButton.TextScaled = true
StopButton.TextColor3 = Color3.new(1, 1, 1)
StopButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
StopButton.BackgroundTransparency = 0.3
StopButton.Text = "Stop"
StopButton.Font = Enum.Font.GothamBold
StopButton.Visible = false
Corner:Clone().Parent = StopButton
StopButton.Parent = BackFrame

local StopStroke = Instance.new("UIStroke")
StopStroke.Color = Color3.fromRGB(80, 80, 80)
StopStroke.Thickness = 1
StopStroke.Transparency = 0.5
StopStroke.Parent = StopButton

local RecordingList = Instance.new("ScrollingFrame")
RecordingList.Name = "RecordingList"
RecordingList.Size = UDim2.new(0.12, 0, 0.3, 0)
RecordingList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordingList.AutomaticCanvasSize = Enum.AutomaticSize.Y
RecordingList.ScrollingDirection = Enum.ScrollingDirection.Y
RecordingList.AnchorPoint = Vector2.new(0.5, 0)
RecordingList.Position = UDim2.new(0.95, 0, 0.66, 0)
RecordingList.BackgroundTransparency = 1
RecordingList.ScrollBarThickness = 2
RecordingList.BorderSizePixel = 0
RecordingList.Parent = BackFrame

local RecordingListLayout = Instance.new("UIListLayout")
RecordingListLayout.Padding = UDim.new(0, 5)
RecordingListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
RecordingListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
RecordingListLayout.SortOrder = Enum.SortOrder.LayoutOrder
RecordingListLayout.Parent = RecordingList

local function RefreshRecordingList()
	for _, child in pairs(RecordingList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	for i, recording in pairs(SavedRecordings) do
		local ItemFrame = Instance.new("Frame")
		ItemFrame.Size = UDim2.new(0.95, 0, 0, 30)
		ItemFrame.BackgroundTransparency = 0.5
		ItemFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		ItemFrame.BorderSizePixel = 0
		Corner:Clone().Parent = ItemFrame
		
		local PlayBtn = Instance.new("TextButton")
		PlayBtn.Size = UDim2.new(0.8, 0, 1, 0)
		PlayBtn.Position = UDim2.new(0, 0, 0, 0)
		PlayBtn.BackgroundTransparency = 1
		PlayBtn.Text = "  " .. recording.name
		PlayBtn.TextColor3 = Color3.new(1, 1, 1)
		PlayBtn.TextScaled = true
		PlayBtn.Font = Enum.Font.Gotham
		PlayBtn.TextXAlignment = Enum.TextXAlignment.Left
		PlayBtn.Parent = ItemFrame
		
		local NameBox = Instance.new("TextBox")
		NameBox.Size = UDim2.new(0.8, 0, 1, 0)
		NameBox.Position = UDim2.new(0, 0, 0, 0)
		NameBox.BackgroundTransparency = 1
		NameBox.Text = recording.name
		NameBox.TextColor3 = Color3.new(1, 1, 1)
		NameBox.TextScaled = true
		NameBox.Font = Enum.Font.Gotham
		NameBox.TextXAlignment = Enum.TextXAlignment.Left
		NameBox.Visible = false
		NameBox.Parent = ItemFrame
		
		local DeleteBtn = Instance.new("TextButton")
		DeleteBtn.Size = UDim2.new(0.15, 0, 0.8, 0)
		DeleteBtn.AnchorPoint = Vector2.new(1, 0.5)
		DeleteBtn.Position = UDim2.new(0.98, 0, 0.5, 0)
		DeleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		DeleteBtn.BackgroundTransparency = 0.3
		DeleteBtn.Text = "X"
		DeleteBtn.TextColor3 = Color3.new(1, 1, 1)
		DeleteBtn.TextScaled = true
		DeleteBtn.Font = Enum.Font.GothamBold
		Corner:Clone().Parent = DeleteBtn
		DeleteBtn.Parent = ItemFrame
		
		ItemFrame.Parent = RecordingList
		
		DeleteBtn.MouseButton1Click:Connect(function()
			table.remove(SavedRecordings, i)
			WriteFileFunc("EmoteRecordings.txt", HttpService:JSONEncode(SavedRecordings))
			RefreshRecordingList()
		end)
		
		PlayBtn.MouseButton2Up:Connect(function()
			PlayBtn.Visible = false
			NameBox.Visible = true
			NameBox:CaptureFocus()
		end)
		
		NameBox.FocusLost:Connect(function()
			PlayBtn.Visible = true
			NameBox.Visible = false
			if NameBox.Text ~= "" then
				SavedRecordings[i].name = NameBox.Text
				PlayBtn.Text = "  " .. NameBox.Text
				WriteFileFunc("EmoteRecordings.txt", HttpService:JSONEncode(SavedRecordings))
			end
		end)
		
		PlayBtn.MouseButton1Click:Connect(function()
			task.spawn(function()
				if IsRecording then return end
				SendNotification("Playback", "Playing " .. recording.name .. "...")
				local startTime = tick()
				
				for _, event in ipairs(recording.data) do
					local targetTime = event.time
					local currentElapsed = tick() - startTime
					local waitDuration = targetTime - currentElapsed
					
					if waitDuration > 0 then
						task.wait(waitDuration)
					end
					
					local char = Players.LocalPlayer.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if not hum then continue end
					
					if event.id == "STOP" then
						-- Stop active animations
						if activeAnimTrack then
							activeAnimTrack:Stop()
							activeAnimTrack:Destroy()
							activeAnimTrack = nil
						end
						activeAnimId = nil
						if activeAnimBtn then
							TweenService:Create(activeAnimBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
							if activeAnimBtn:FindFirstChild("TextLabel") then
								TweenService:Create(activeAnimBtn.TextLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
							end
							activeAnimBtn = nil
						end
						if CurrentPlayingTrack then
							pcall(function() CurrentPlayingTrack:Stop() end)
							CurrentPlayingTrack = nil
						end
						continue
					end

					-- Check source to determine how to play
					if event.source == "AnimTab" then
						-- AnimGUI animation - play directly like the button does
						print("[PLAYBACK] Playing AnimTab:", event.name, event.id)
						
						-- Stop previous animation
						if activeAnimTrack then
							activeAnimTrack:Stop()
							activeAnimTrack:Destroy()
							activeAnimTrack = nil
						end
						
						-- Load and play the animation
						local anim = Instance.new("Animation")
						anim.AnimationId = event.id
						local track = hum:LoadAnimation(anim)
						
						if track then
							track:Play()
							activeAnimTrack = track
							activeAnimId = event.id
							print("[PLAYBACK] AnimTab animation playing:", event.name)
						end
					else
						-- Emote wheel animation - use PlayEmote
						print("[PLAYBACK] Playing Emote:", event.name, event.id)
						
						if CurrentPlayingTrack then
							pcall(function() CurrentPlayingTrack:Stop() end)
							CurrentPlayingTrack = nil
						end
						
						local track = PlayEmote(event.name, event.id)
						if track and typeof(track) == "Instance" and track:IsA("AnimationTrack") then
							CurrentPlayingTrack = track
						end
					end
				end
				
				-- Cleanup at end
				CurrentPlayingTrack = nil
				activeAnimTrack = nil
				activeAnimId = nil
				if activeAnimBtn then
					TweenService:Create(activeAnimBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
					if activeAnimBtn:FindFirstChild("TextLabel") then
						TweenService:Create(activeAnimBtn.TextLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
					end
					activeAnimBtn = nil
				end
			end)
		end)
	end
end

local AwaitingKeybind = false

local function FireAvatarSwitch()
	local refreshEvent = ReplicatedStorage:FindFirstChild("event_modify_refresh")
	if refreshEvent then
		refreshEvent:FireServer(Players.LocalPlayer)
		SendNotification("Avatar Switch", "Avatar refreshed!")
	else
		SendNotification("Error", "Refresh event not found!")
	end
end

AvatarSwitchButton.MouseButton1Click:Connect(FireAvatarSwitch)

local function openemotes(name, state, input)
	if state == Enum.UserInputState.Begin then
		if ClassicModeEnabled then
			StopClassicMode()
			ScreenGui.Enabled = true
		else
			ScreenGui.Enabled = not ScreenGui.Enabled
		end
	end
end

if IsStudio then
	ContextActionService:BindActionAtPriority("Emote Menu", openemotes, true, 2001, Enum.KeyCode.Comma)
else
	ContextActionService:BindCoreActionAtPriority("Emote Menu", openemotes, true, 2001, Enum.KeyCode.Comma)
end

KeybindButton.MouseButton1Click:Connect(function()
	AwaitingKeybind = true
	KeybindButton.Text = "..."
	KeybindButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
end)

local SearchBar = Instance.new("TextBox")
SearchBar.BorderSizePixel = 0
SearchBar.AnchorPoint = Vector2.new(0.5, 0.5)
SearchBar.Position = UDim2.new(1, 0, -0.055, 0)
SearchBar.Size = UDim2.new(0.1, 0, 0.04, 0)
SearchBar.TextScaled = true
SearchBar.PlaceholderText = "Search"
SearchBar.TextColor3 = Color3.new(1, 1, 1)
SearchBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SearchBar.BackgroundTransparency = 0.3
SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
	local text = SearchBar.Text:lower():sub(1, 50)
	if SearchBar.Text ~= text then SearchBar.Text = text end
	for _, button in pairs(Frame:GetChildren()) do
		if button:IsA("GuiButton") then
			local name = button:GetAttribute("name")
			if name then
				button.Visible = text == "" or name:lower():match(text)
			end
		end
	end
end)
Corner:Clone().Parent = SearchBar
SearchBar.Parent = BackFrame

local SearchStroke = Instance.new("UIStroke")
SearchStroke.Color = Color3.fromRGB(80, 80, 80)
SearchStroke.Thickness = 1
SearchStroke.Transparency = 0.5
SearchStroke.Parent = SearchBar

local inputconnect
ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if ScreenGui.Enabled then
		EmoteName.Text = "Select an Emote"
		SearchBar.Text = ""
		SortFrame.Visible = false
		GuiService:SetEmotesMenuOpen(false)
		inputconnect = UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
				ScreenGui.Enabled = false
			end
		end)
	elseif inputconnect then
		inputconnect:Disconnect()
	end
end)

local AddEmoteButton = Instance.new("TextButton")
AddEmoteButton.BorderSizePixel = 0
AddEmoteButton.AnchorPoint = Vector2.new(0.5, 0.5)
AddEmoteButton.Position = UDim2.new(1, 0, 0, 0)
AddEmoteButton.Size = UDim2.new(0.1, 0, 0.04, 0)
AddEmoteButton.TextScaled = true
AddEmoteButton.TextColor3 = Color3.new(1, 1, 1)
AddEmoteButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AddEmoteButton.BackgroundTransparency = 0.3
AddEmoteButton.Text = "Add Emote"
AddEmoteButton.Font = Enum.Font.GothamBold
AddEmoteButton.MouseButton1Click:Connect(function()
	CustomEmoteFrame.Visible = not CustomEmoteFrame.Visible
end)
Corner:Clone().Parent = AddEmoteButton
AddEmoteButton.Parent = BackFrame

local AddEmoteStroke = Instance.new("UIStroke")
AddEmoteStroke.Color = Color3.fromRGB(80, 80, 80)
AddEmoteStroke.Thickness = 1
AddEmoteStroke.Transparency = 0.5
AddEmoteStroke.Parent = AddEmoteButton

local MadeByLabel = Instance.new("TextLabel")
MadeByLabel.Text = "Made By Za1k.                  Version: 2.8.3 🥴"
MadeByLabel.TextScaled = true
MadeByLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MadeByLabel.BackgroundTransparency = 0.3
MadeByLabel.TextColor3 = Color3.new(1, 1, 1)
MadeByLabel.BorderSizePixel = 0
MadeByLabel.AnchorPoint = Vector2.new(0.5, 0.5)
MadeByLabel.Position = UDim2.new(1.02, 0, 1, 0)
MadeByLabel.Size = UDim2.new(0.25, 0, 0.06, 0)
MadeByLabel.Font = Enum.Font.GothamBold
Corner:Clone().Parent = MadeByLabel
MadeByLabel.Parent = BackFrame

if not IsStudio then
	GuiService.EmotesMenuOpenChanged:Connect(function(isopen)
		if isopen then ScreenGui.Enabled = false end
	end)
end

GuiService.MenuOpened:Connect(function()
	ScreenGui.Enabled = false
end)

if not game:IsLoaded() then game.Loaded:Wait() end

local LocalPlayer = Players.LocalPlayer

if IsStudio then
	ScreenGui.Parent = LocalPlayer.PlayerGui
else
	local SynV3 = syn and DrawingImmediate
	if (not is_sirhurt_closure) and (not SynV3) and (syn and syn.protect_gui) then
		syn.protect_gui(ScreenGui)
		ScreenGui.Parent = CoreGui
	elseif get_hidden_gui or gethui then
		ScreenGui.Parent = (get_hidden_gui or gethui)()
	else
		ScreenGui.Parent = CoreGui
	end
end

local function WaitForChildOfClass(parent, class)
	local child = parent:FindFirstChildOfClass(class)
	while not child or child.ClassName ~= class do
		child = parent.ChildAdded:Wait()
	end
	return child
end

local params = CatalogSearchParams.new()
params.AssetTypes = {Enum.AvatarAssetType.EmoteAnimation}
params.SortType = Enum.CatalogSortType.RecentlyCreated
params.SortAggregation = Enum.CatalogSortAggregation.AllTime
params.IncludeOffSale = true
params.CreatorName = "Roblox"
params.Limit = 120

local function getCatalogPage()
	local success, catalogPage = pcall(function()
		return AvatarEditorService:SearchCatalog(params)
	end)
	if not success then
		task.wait(5)
		return getCatalogPage()
	end
	return catalogPage
end

local catalogPage = getCatalogPage()
local pages = {}

while true do
	table.insert(pages, catalogPage:GetCurrentPage())
	if catalogPage.IsFinished then break end
	local function AdvanceToNextPage()
		local success = pcall(function() catalogPage:AdvanceToNextPageAsync() end)
		if not success then
			task.wait(5)
			return AdvanceToNextPage()
		end
	end
	AdvanceToNextPage()
end

for _, page in pairs(pages) do
	for _, emote in pairs(page) do
		AddEmote(emote.Name, emote.Id, emote.Price)
	end
end

-- EXTRA EMOTES
AddEmote("Sitting", 139621472081340)
AddEmote("Naked", 15571538346)
AddEmote("Huego Drive", 17360720445)
AddEmote("Hand Stand", 124055618254120)
AddEmote("dead", 119400441490983)
AddEmote("patty cake2", 76124649545220)
AddEmote("patty cake", 120642514156293)
AddEmote("Ghostly", 124071723800586)
AddEmote("Roll", 130726889233022)
AddEmote("Angles", 75837489916720)
AddEmote("Oof", 110740075367686)
AddEmote("imagination", 18443268949)
AddEmote("abcd", 129297813295515)
AddEmote("Side Stepper", 14024722653)
AddEmote("Around", 16215060261)
AddEmote("low", 10214411646)
AddEmote("talking", 6303091119)
AddEmote("talking", 134615135651900)
AddEmote("twicee", 14900153406)
AddEmote("archer", 13823339506)
AddEmote("egirl", 117809429848082)
AddEmote("sab", 80652345815019)

Loading:Destroy()

table.sort(Emotes, function(a, b) return a.index < b.index end)
for i, v in pairs(Emotes) do v.sort.newestfirst = i end

table.sort(Emotes, function(a, b) return a.index > b.index end)
for i, v in pairs(Emotes) do v.sort.oldestfirst = i end

table.sort(Emotes, function(a, b) return a.name:lower() < b.name:lower() end)
for i, v in pairs(Emotes) do v.sort.alphabeticfirst = i end

table.sort(Emotes, function(a, b) return a.name:lower() > b.name:lower() end)
for i, v in pairs(Emotes) do v.sort.alphabeticlast = i end

table.sort(Emotes, function(a, b) return a.price < b.price end)
for i, v in pairs(Emotes) do v.sort.lowestprice = i end

table.sort(Emotes, function(a, b) return a.price > b.price end)
for i, v in pairs(Emotes) do v.sort.highestprice = i end

-- LOAD FILES
if not IsStudio then
	if IsFileFunc("FavoritedEmotes.txt") then
		pcall(function() FavoritedEmotes = HttpService:JSONDecode(ReadFileFunc("FavoritedEmotes.txt")) end)
	else
		WriteFileFunc("FavoritedEmotes.txt", HttpService:JSONEncode(FavoritedEmotes))
	end
	
	if IsFileFunc("CustomEmotes.txt") then
		pcall(function()
			CustomEmotes = HttpService:JSONDecode(ReadFileFunc("CustomEmotes.txt"))
			for _, customEmote in pairs(CustomEmotes) do
				AddEmote(customEmote.name, customEmote.id, 0)
			end
		end)
	else
		WriteFileFunc("CustomEmotes.txt", HttpService:JSONEncode(CustomEmotes))
	end
	
	if IsFileFunc("CustomEmoteOrder.txt") then
		pcall(function() CustomEmoteOrder = HttpService:JSONDecode(ReadFileFunc("CustomEmoteOrder.txt")) end)
	elseif IsFileFunc("CustomEmoteOrder") then
		pcall(function() CustomEmoteOrder = HttpService:JSONDecode(ReadFileFunc("CustomEmoteOrder")) end)
	else
		WriteFileFunc("CustomEmoteOrder.txt", HttpService:JSONEncode(CustomEmoteOrder))
	end
    
    -- Sync custom order to Emotes table
    for _, e in pairs(Emotes) do
        local order = CustomEmoteOrder[tostring(e.id)]
        if order then e.customOrder = order end
    end
	
	if IsFileFunc("FavoritesVisible.txt") then
		pcall(function()
			local data = HttpService:JSONDecode(ReadFileFunc("FavoritesVisible.txt"))
			FavoritesVisible = data.visible
		end)
	else
		WriteFileFunc("FavoritesVisible.txt", HttpService:JSONEncode({visible = FavoritesVisible}))
	end
	
	if IsFileFunc("AvatarSwitchKeybind.txt") then
		pcall(function()
			local data = HttpService:JSONDecode(ReadFileFunc("AvatarSwitchKeybind.txt"))
			AvatarSwitchKeybind = Enum.KeyCode[data.keybind] or Enum.KeyCode.G
			KeybindButton.Text = AvatarSwitchKeybind.Name
		end)
	else
		WriteFileFunc("AvatarSwitchKeybind.txt", HttpService:JSONEncode({keybind = "G"}))
	end
	
	if IsFileFunc("AutoCloseEmote.txt") then
		pcall(function()
			local data = HttpService:JSONDecode(ReadFileFunc("AutoCloseEmote.txt"))
			CloseAfterEmote = data.enabled
			AutoCloseButton.Text = CloseAfterEmote and "Auto Close: ON" or "Auto Close: OFF"
		end)
	else
		WriteFileFunc("AutoCloseEmote.txt", HttpService:JSONEncode({enabled = CloseAfterEmote}))
	end

	if IsFileFunc("EmoteRecordings.txt") then
		pcall(function()
			SavedRecordings = HttpService:JSONDecode(ReadFileFunc("EmoteRecordings.txt"))
		end)
	else
		WriteFileFunc("EmoteRecordings.txt", HttpService:JSONEncode(SavedRecordings))
	end
	
	RefreshRecordingList()
end

-- INPUTS
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if AwaitingKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
		AvatarSwitchKeybind = input.KeyCode
		KeybindButton.Text = input.KeyCode.Name
		KeybindButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		AwaitingKeybind = false
		WriteFileFunc("AvatarSwitchKeybind.txt", HttpService:JSONEncode({keybind = input.KeyCode.Name}))
		SendNotification("Keybind Set", "Avatar Switch keybind set to " .. input.KeyCode.Name)
		return
	end
	if input.KeyCode == AvatarSwitchKeybind then
		FireAvatarSwitch()
	end
	if input.KeyCode == Enum.KeyCode.Period then
		if ClassicModeEnabled then
			StopClassicMode()
		else
			StartClassicMode()
		end
	end
end)

-- RECORDER BUTTONS
RecordButton.MouseButton1Click:Connect(function()
	if IsRecording then return end
	local LocalPlayer = Players.LocalPlayer
	local Character = LocalPlayer and LocalPlayer.Character
	local Humanoid = Character and Character:FindFirstChild("Humanoid")
	if not Humanoid then return end

	IsRecording = true
	CurrentRecordingTrack = {}
	RecordingStartTime = tick()
	RecordButton.Visible = false
	StopButton.Visible = true
	
	local function ScanPlaying()
		for _, track in pairs(Humanoid:GetPlayingAnimationTracks()) do
			local id = track.Animation.AnimationId
			local cleanId = tonumber(id:match("%d+"))
			if not cleanId then continue end
			local name = "Unknown"
			for _, e in pairs(Emotes) do
				if e.id == cleanId then name = e.name break end
			end
			if name == "Unknown" and (track.Priority == Enum.AnimationPriority.Idle or track.Priority == Enum.AnimationPriority.Core) then
				continue
			end
			table.insert(CurrentRecordingTrack, {
				id = cleanId,
				name = name,
				time = tick() - RecordingStartTime
			})
		end
	end
	ScanPlaying()
	
	RecordingConnection = Humanoid.AnimationPlayed:Connect(function(track)
		local id = track.Animation.AnimationId
		local cleanId = tonumber(id:match("%d+"))
		if not cleanId then return end
		
		-- De-duplication: Skip if already recorded by UI hook within last 0.1s
		if #CurrentRecordingTrack > 0 then
			local last = CurrentRecordingTrack[#CurrentRecordingTrack]
			if last.id == cleanId and (tick() - RecordingStartTime - last.time) < 0.1 then return end
		end

		local name = "Unknown"
		local isKnown = false
		for _, e in pairs(Emotes) do
			if e.id == cleanId then name = e.name isKnown = true break end
		end
		if not isKnown and (track.Priority == Enum.AnimationPriority.Idle or track.Priority == Enum.AnimationPriority.Core) then
			return
		end
		if #CurrentRecordingTrack > 0 then
			local last = CurrentRecordingTrack[#CurrentRecordingTrack]
			if last.id == cleanId and (tick() - RecordingStartTime - last.time) < 0.6 then return end
		end
		table.insert(CurrentRecordingTrack, {
			id = cleanId,
			name = name,
			time = tick() - RecordingStartTime,
			source = "Internal"
		})
	end)
	SendNotification("Recorder", "Recording started!")
end)

StopButton.MouseButton1Click:Connect(function()
	if not IsRecording then return end
	IsRecording = false
	RecordButton.Visible = true
	StopButton.Visible = false
	if RecordingConnection then RecordingConnection:Disconnect() end
	local StopTime = tick() - RecordingStartTime
	if #CurrentRecordingTrack > 0 then
		local CleanTrack = {}
		for i = 1, #CurrentRecordingTrack do
			local cur = CurrentRecordingTrack[i]
			local dur = (CurrentRecordingTrack[i+1] and CurrentRecordingTrack[i+1].time or StopTime) - cur.time
			if dur > 0.05 then cur.duration = dur table.insert(CleanTrack, cur) end
		end
		if #CleanTrack > 0 then
			table.insert(SavedRecordings, {name = "Recording " .. (#SavedRecordings + 1), data = CleanTrack})
			WriteFileFunc("EmoteRecordings.txt", HttpService:JSONEncode(SavedRecordings))
			RefreshRecordingList()
		end
	end
end)

local function ToggleFavoriteButtons()
	FavoritesVisible = not FavoritesVisible
	for _, emoteButton in pairs(Frame:GetChildren()) do
		if emoteButton:IsA("GuiButton") then
			local fav = emoteButton:FindFirstChild("favorite")
			if fav then fav.Visible = FavoritesVisible end
		end
	end
	local toggleBtn = Frame:FindFirstChild("HideFavoritesBtn")
	if toggleBtn then
		toggleBtn.Text = FavoritesVisible and "Hide Favorites" or "Show Favorites"
	end
	WriteFileFunc("FavoritesVisible.txt", HttpService:JSONEncode({visible = FavoritesVisible}))
end

local function CreateEmoteButton(Emote, Description, Ratio)
	Description:AddEmote(Emote.name, Emote.id)
	local EmoteButton = Instance.new("ImageButton")
	local IsFavorited = table.find(FavoritedEmotes, Emote.id)
	
	if CustomEmoteOrder[tostring(Emote.id)] then
		EmoteButton.LayoutOrder = CustomEmoteOrder[tostring(Emote.id)]
	else
		local sortValue = (Emote.sort and Emote.sort[CurrentSort]) or Emote.index or 0
		EmoteButton.LayoutOrder = sortValue + ((IsFavorited and 0) or #Emotes)
	end
	
	EmoteButton.Name = tostring(Emote.id)
	EmoteButton:SetAttribute("name", Emote.name)
	Corner:Clone().Parent = EmoteButton
	EmoteButton.Image = Emote.icon
	EmoteButton.BackgroundTransparency = 0.5
	EmoteButton.BackgroundColor3 = Color3.new(0, 0, 0)
	EmoteButton.BorderSizePixel = 0
	Ratio:Clone().Parent = EmoteButton
	
	local ButtonStroke = Instance.new("UIStroke")
	ButtonStroke.Color = Color3.fromRGB(80, 80, 80)
	ButtonStroke.Thickness = 1
	ButtonStroke.Transparency = 0.5
	ButtonStroke.Parent = EmoteButton
	
	local EmoteNumber = Instance.new("TextLabel")
	EmoteNumber.Name = "number"
	EmoteNumber.TextScaled = true
	EmoteNumber.BackgroundTransparency = 1
	EmoteNumber.TextColor3 = Color3.new(1, 1, 1)
	EmoteNumber.BorderSizePixel = 0
	EmoteNumber.AnchorPoint = Vector2.new(0.5, 0.5)
	EmoteNumber.Size = UDim2.new(0.2, 0, 0.2, 0)
	EmoteNumber.Position = UDim2.new(0.1, 0, 0.9, 0)
	EmoteNumber.Text = tostring((Emote.sort and Emote.sort[CurrentSort]) or Emote.index or "")
	EmoteNumber.TextXAlignment = Enum.TextXAlignment.Center
	EmoteNumber.TextYAlignment = Enum.TextYAlignment.Center
	EmoteNumber.Font = Enum.Font.GothamBold
	local UIStroke = Instance.new("UIStroke")
	UIStroke.Transparency = 0.5
	UIStroke.Parent = EmoteNumber
	EmoteNumber.Parent = EmoteButton
	EmoteButton.Parent = Frame
    
	EmoteButton.MouseButton1Click:Connect(function()
		if not DraggingEmote then
			PlayEmote(Emote.name, Emote.id)
		else
			local dragOrder = DraggingEmote.button.LayoutOrder
			local targetOrder = EmoteButton.LayoutOrder
			DraggingEmote.button.LayoutOrder = targetOrder
			EmoteButton.LayoutOrder = dragOrder
			
			CustomEmoteOrder[tostring(DraggingEmote.id)] = targetOrder
			CustomEmoteOrder[tostring(Emote.id)] = dragOrder
			
			WriteFileFunc("CustomEmoteOrder.txt", HttpService:JSONEncode(CustomEmoteOrder))
			DraggingEmote.button.BackgroundColor3 = Color3.new(0, 0, 0)
			DraggingEmote.button.BackgroundTransparency = 0.5
			DraggingEmote = nil
		end
	end)
	
	EmoteButton.MouseButton2Down:Connect(function()
		DraggingEmote = {button = EmoteButton, id = Emote.id, originalOrder = EmoteButton.LayoutOrder}
		EmoteButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
		EmoteButton.BackgroundTransparency = 0.2
	end)
	
	EmoteButton.MouseButton2Up:Connect(function()
		task.wait(0.1)
		if DraggingEmote then
			DraggingEmote.button.BackgroundColor3 = Color3.new(0, 0, 0)
			DraggingEmote.button.BackgroundTransparency = 0.5
			DraggingEmote = nil
		end
	end)
	
	EmoteButton.MouseEnter:Connect(function()
		EmoteName.Text = Emote.name
		if DraggingEmote and DraggingEmote.id ~= Emote.id then
			EmoteButton.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
			EmoteButton.BackgroundTransparency = 0.2
		end
	end)
	
	EmoteButton.MouseLeave:Connect(function()
		if not DraggingEmote or DraggingEmote.id ~= Emote.id then
			EmoteButton.BackgroundColor3 = Color3.new(0, 0, 0)
			EmoteButton.BackgroundTransparency = 0.5
		end
	end)
	
	local Favorite = Instance.new("ImageButton")
	Favorite.Name = "favorite"
	Favorite.Image = table.find(FavoritedEmotes, Emote.id) and FavoriteOn or FavoriteOff
	Favorite.AnchorPoint = Vector2.new(0.5, 0.5)
	Favorite.Size = UDim2.new(0.1, 0, 0.1, 0)
	Favorite.Position = UDim2.new(0.9, 0, 0.9, 0)
	Favorite.BorderSizePixel = 0
	Favorite.BackgroundTransparency = 1
	Favorite.Visible = FavoritesVisible
	Favorite.Parent = EmoteButton
	Favorite.MouseButton1Click:Connect(function()
		local index = table.find(FavoritedEmotes, Emote.id)
		if index then
			table.remove(FavoritedEmotes, index)
			Favorite.Image = FavoriteOff
			EmoteButton.LayoutOrder = Emote.sort[CurrentSort] + #Emotes
		else
			table.insert(FavoritedEmotes, Emote.id)
			Favorite.Image = FavoriteOn
			EmoteButton.LayoutOrder = Emote.sort[CurrentSort]
		end
		WriteFileFunc("FavoritedEmotes.txt", HttpService:JSONEncode(FavoritedEmotes))
	end)
	
	return EmoteButton
end
AddCustomEmoteButton.MouseButton1Click:Connect(function()
	local emoteName = CustomEmoteNameBox.Text
	local emoteID = tonumber(CustomEmoteIDBox.Text)
	local emoteOrder = tonumber(CustomEmoteOrderBox.Text)
	if emoteName ~= "" and emoteID then
		local customEmoteData = {name = emoteName, id = emoteID}
		if emoteOrder then customEmoteData.order = emoteOrder end
		table.insert(CustomEmotes, customEmoteData)
		AddEmote(emoteName, emoteID, 0)
		if emoteOrder then
			CustomEmoteOrder[tostring(emoteID)] = emoteOrder
			WriteFileFunc("CustomEmoteOrder.txt", HttpService:JSONEncode(CustomEmoteOrder))
		end
		WriteFileFunc("CustomEmotes.txt", HttpService:JSONEncode(CustomEmotes))
		CustomEmoteFrame.Visible = false
		local Character = LocalPlayer.Character
		if Character then
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				local Description = Humanoid:FindFirstChildOfClass("HumanoidDescription")
				if Description then
					local Ratio = Instance.new("UIAspectRatioConstraint")
					Ratio.AspectType = Enum.AspectType.ScaleWithParentSize
					CreateEmoteButton(Emotes[#Emotes], Description, Ratio)
				end
			end
		end
	end
end)

-- ANIM GUI SECTION
local animGuiAnimations = {
	{n = "Handstand", i = "rbxassetid://13027233338", order = 1},
	{n = "VIP 01", i = "rbxassetid://14852252548", order = 2},
	{n = "VIP 03", i = "rbxassetid://137445502103066", order = 3},
	{n = "VIP 08", i = "rbxassetid://11137338685", order = 4},
	{n = "VIP 09", i = "rbxassetid://11136806744", order = 5},
	{n = "Ghostly", i = "rbxassetid://124385779438289", order = 6},
	{n = "Oof", i = "rbxassetid://134763058840745", order = 7},
	{n = "Die", i = "rbxassetid://14852161489", order = 8},
	{n = "Log", i = "rbxassetid://116818881329505", order = 9},
	{n = "blow", i = "rbxassetid://124072584017964", order = 10}
}

-- Ensure AnimGUI emotes are registered
for _, animData in ipairs(animGuiAnimations) do
	local cleanId = tonumber(animData.i:match("%d+"))
	if cleanId then
		AddEmote(animData.n, cleanId, 0)
	end
end

local isHorizontalAnim = false
local showNumbersAnim = false

local AnimGui = Instance.new("ScreenGui")
AnimGui.Name = "AnimGUI"
AnimGui.ResetOnSpawn = false
AnimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if IsStudio then AnimGui.Parent = LocalPlayer.PlayerGui else AnimGui.Parent = (get_hidden_gui or gethui or function() return CoreGui end)() end

local animMain = Instance.new("Frame")
animMain.Size = UDim2.new(0, 260, 0, 214)
animMain.Position = UDim2.new(0.015, 0, 0.25, 0)
animMain.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
animMain.BorderSizePixel = 0
animMain.Active = true
animMain.Draggable = true
animMain.Parent = AnimGui

local animMainStroke = Instance.new("UIStroke")
animMainStroke.Color = Color3.fromRGB(35, 35, 35)
animMainStroke.Thickness = 1
animMainStroke.Parent = animMain

local animTopBar = Instance.new("Frame")
animTopBar.Size = UDim2.new(1, 0, 0, 30)
animTopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
animTopBar.BorderSizePixel = 0
animTopBar.Parent = animMain

local animTopBarLine = Instance.new("Frame")
animTopBarLine.Size = UDim2.new(1, 0, 0, 1)
animTopBarLine.Position = UDim2.new(0, 0, 1, 0)
animTopBarLine.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
animTopBarLine.BorderSizePixel = 0
animTopBarLine.Parent = animTopBar

local animTitle = Instance.new("TextLabel")
animTitle.Size = UDim2.new(1, -80, 1, 0)
animTitle.Position = UDim2.new(0, 10, 0, 0)
animTitle.BackgroundTransparency = 1
animTitle.Text = "ANIMATIONS"
animTitle.Font = Enum.Font.GothamBold
animTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
animTitle.TextSize = 14
animTitle.TextXAlignment = Enum.TextXAlignment.Left
animTitle.Parent = animTopBar

local animNumberBtn = Instance.new("TextButton")
animNumberBtn.Size = UDim2.new(0, 30, 0, 20)
animNumberBtn.Position = UDim2.new(1, -68, 0.5, -10)
animNumberBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
animNumberBtn.BorderSizePixel = 0
animNumberBtn.Text = "#"
animNumberBtn.Font = Enum.Font.GothamBold
animNumberBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
animNumberBtn.TextSize = 16
animNumberBtn.AutoButtonColor = false
animNumberBtn.Parent = animTopBar

local animNumberStroke = Instance.new("UIStroke")
animNumberStroke.Color = Color3.fromRGB(35, 35, 35)
animNumberStroke.Thickness = 1
animNumberStroke.Parent = animNumberBtn

local animToggleBtn = Instance.new("TextButton")
animToggleBtn.Size = UDim2.new(0, 30, 0, 20)
animToggleBtn.Position = UDim2.new(1, -38, 0.5, -10)
animToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
animToggleBtn.BorderSizePixel = 0
animToggleBtn.Text = "⇄"
animToggleBtn.Font = Enum.Font.GothamBold
animToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
animToggleBtn.TextSize = 16
animToggleBtn.AutoButtonColor = false
animToggleBtn.Parent = animTopBar

local animToggleStroke = Instance.new("UIStroke")
animToggleStroke.Color = Color3.fromRGB(35, 35, 35)
animToggleStroke.Thickness = 1
animToggleStroke.Parent = animToggleBtn

local animContainer = Instance.new("Frame")
animContainer.Size = UDim2.new(1, -16, 1, -42)
animContainer.Position = UDim2.new(0, 8, 0, 38)
animContainer.BackgroundTransparency = 1
animContainer.BorderSizePixel = 0
animContainer.ClipsDescendants = true
animContainer.Parent = animMain

local animLayout = Instance.new("UIGridLayout")
animLayout.CellPadding = UDim2.new(0, 6, 0, 6)
animLayout.CellSize = UDim2.new(0.48, 0, 0, 30)
animLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
animLayout.SortOrder = Enum.SortOrder.LayoutOrder
animLayout.Parent = animContainer

local reorderUI = Instance.new("Frame")
reorderUI.Size = UDim2.new(0, 300, 0, 400)
reorderUI.Position = UDim2.new(0.5, -150, 0.5, -200)
reorderUI.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
reorderUI.BorderSizePixel = 0
reorderUI.Visible = false
reorderUI.Parent = AnimGui

local reorderStroke = Instance.new("UIStroke")
reorderStroke.Color = Color3.fromRGB(35, 35, 35)
reorderStroke.Thickness = 1
reorderStroke.Parent = reorderUI

local reorderTopBar = Instance.new("Frame")
reorderTopBar.Size = UDim2.new(1, 0, 0, 35)
reorderTopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
reorderTopBar.BorderSizePixel = 0
reorderTopBar.Parent = reorderUI

local reorderTopLine = Instance.new("Frame")
reorderTopLine.Size = UDim2.new(1, 0, 0, 1)
reorderTopLine.Position = UDim2.new(0, 0, 1, 0)
reorderTopLine.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
reorderTopLine.BorderSizePixel = 0
reorderTopLine.Parent = reorderTopBar

local reorderTitle = Instance.new("TextLabel")
reorderTitle.Size = UDim2.new(1, -50, 1, 0)
reorderTitle.Position = UDim2.new(0, 10, 0, 0)
reorderTitle.BackgroundTransparency = 1
reorderTitle.Text = "REORDER ANIMATIONS"
reorderTitle.Font = Enum.Font.GothamBold
reorderTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
reorderTitle.TextSize = 13
reorderTitle.TextXAlignment = Enum.TextXAlignment.Left
reorderTitle.Parent = reorderTopBar

local reorderCloseBtn = Instance.new("TextButton")
reorderCloseBtn.Size = UDim2.new(0, 25, 0, 25)
reorderCloseBtn.Position = UDim2.new(1, -30, 0, 5)
reorderCloseBtn.BackgroundTransparency = 1
reorderCloseBtn.BorderSizePixel = 0
reorderCloseBtn.Text = "×"
reorderCloseBtn.Font = Enum.Font.GothamBold
reorderCloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
reorderCloseBtn.TextSize = 20
reorderCloseBtn.AutoButtonColor = false
reorderCloseBtn.Parent = reorderTopBar

local reorderScroll = Instance.new("ScrollingFrame")
reorderScroll.Size = UDim2.new(1, -20, 1, -55)
reorderScroll.Position = UDim2.new(0, 10, 0, 45)
reorderScroll.BackgroundTransparency = 1
reorderScroll.BorderSizePixel = 0
reorderScroll.ScrollBarThickness = 4
reorderScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
reorderScroll.CanvasSize = UDim2.new(0, 0, 0, 360)
reorderScroll.Parent = reorderUI

local reorderList = Instance.new("UIListLayout")
reorderList.Padding = UDim.new(0, 6)
reorderList.SortOrder = Enum.SortOrder.LayoutOrder
reorderList.Parent = reorderScroll

local activeAnimTrack = nil
local activeAnimId = nil
local activeAnimBtn = nil

local function saveAnimOrder()
	local orderData = {}
	table.sort(animGuiAnimations, function(a, b) return a.order < b.order end)
	for i, data in ipairs(animGuiAnimations) do
		table.insert(orderData, {n = data.n, o = data.order})
	end
	WriteFileFunc("animationplacementsbyza1k.txt", HttpService:JSONEncode(orderData))
end

local function loadAnimOrder()
	if IsFileFunc("animationplacementsbyza1k.txt") then
		local success, result = pcall(function()
			return HttpService:JSONDecode(ReadFileFunc("animationplacementsbyza1k.txt"))
		end)
		if success and result then
			for _, saved in ipairs(result) do
				for _, data in ipairs(animGuiAnimations) do
					if data.n == saved.n then
						data.order = saved.o
						break
					end
				end
			end
		end
	end
end

local function getSortedAnimGuiAnimations()
	local sorted = {}
	for _, data in ipairs(animGuiAnimations) do
		table.insert(sorted, data)
	end
	table.sort(sorted, function(a, b) return a.order < b.order end)
	return sorted
end

local function updateAnimButtonLabels()
	local sorted = getSortedAnimGuiAnimations()
	for idx, data in ipairs(sorted) do
		for _, btn in ipairs(animContainer:GetChildren()) do
			if btn:IsA("TextButton") and btn.Name == data.n then
				local label = btn:FindFirstChild("TextLabel")
				if label then
					if showNumbersAnim then
						label.Text = data.n .. " #" .. data.order
					else
						label.Text = data.n
					end
				end
				btn.LayoutOrder = data.order
				break
			end
		end
	end
end

local function createReorderItem(data)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, 0, 0, 35)
	item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	item.BorderSizePixel = 0
	item.LayoutOrder = data.order
	item.Parent = reorderScroll

	local itemStroke = Instance.new("UIStroke")
	itemStroke.Color = Color3.fromRGB(35, 35, 35)
	itemStroke.Thickness = 1
	itemStroke.Parent = item

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -80, 1, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.n
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = item

	local numberBox = Instance.new("TextBox")
	numberBox.Size = UDim2.new(0, 50, 0, 25)
	numberBox.Position = UDim2.new(1, -60, 0.5, -12)
	numberBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	numberBox.BorderSizePixel = 0
	numberBox.Text = tostring(data.order)
	numberBox.Font = Enum.Font.Gotham
	numberBox.TextColor3 = Color3.fromRGB(200, 200, 200)
	numberBox.TextSize = 13
	numberBox.ClearTextOnFocus = false
	numberBox.Parent = item

	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = Color3.fromRGB(35, 35, 35)
	boxStroke.Thickness = 1
	boxStroke.Parent = numberBox

	numberBox.FocusLost:Connect(function()
		local num = tonumber(numberBox.Text)
		if num and num >= 1 and num <= #animGuiAnimations and num == math.floor(num) then
			local oldOrder = data.order
			
			for _, otherData in ipairs(animGuiAnimations) do
				if otherData.order == num and otherData ~= data then
					otherData.order = oldOrder
					break
				end
			end
			
			data.order = num
			
			for _, otherItem in ipairs(reorderScroll:GetChildren()) do
				if otherItem:IsA("Frame") then
					otherItem:Destroy()
				end
			end
			
			local sorted = getSortedAnimGuiAnimations()
			for _, animData in ipairs(sorted) do
				createReorderItem(animData)
			end
			
			updateAnimButtonLabels()
			saveAnimOrder()
		else
			numberBox.Text = tostring(data.order)
		end
	end)

	return item
end

-- MODIFIED: This function now hooks into the recording system
local function toggleAnimGuiEmote(id, name, btn)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- Toggle OFF if same button pressed
	if activeAnimId == id then
		if activeAnimTrack then 
			activeAnimTrack:Stop()
			activeAnimTrack:Destroy()
			activeAnimTrack = nil
		end
		activeAnimId = nil
		
		-- Record "STOP" event for accurate durations
		if IsRecording then
			table.insert(CurrentRecordingTrack, {
				id = "STOP",
				name = "Stop",
				time = tick() - RecordingStartTime,
				source = "AnimTab"
			})
			print("[RECORDING] STOP event added to track")
		end
		
		if activeAnimBtn then
			local oldBtn = activeAnimBtn
			TweenService:Create(oldBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
			if oldBtn:FindFirstChild("TextLabel") then
				TweenService:Create(oldBtn.TextLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
			end
			activeAnimBtn = nil
		end
		return
	end

	-- Override existing animation - record STOP first if there was an active one
	if activeAnimTrack then
		if IsRecording then
			table.insert(CurrentRecordingTrack, {
				id = "STOP",
				name = "Stop",
				time = tick() - RecordingStartTime,
				source = "AnimTab"
			})
			print("[RECORDING] Auto-STOP event added (override)")
		end
		activeAnimTrack:Stop()
		activeAnimTrack:Destroy()
		activeAnimTrack = nil
	end

	if activeAnimBtn then
		local oldBtn = activeAnimBtn
		TweenService:Create(oldBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
		if oldBtn:FindFirstChild("TextLabel") then
			TweenService:Create(oldBtn.TextLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
		end
	end

	-- *** RECORDING HOOK FOR ANIMGUI ***
	if IsRecording then
		local recordData = {
			id = id,  -- Store the full rbxassetid:// string
			name = name,
			time = tick() - RecordingStartTime,
			source = "AnimTab"
		}
		table.insert(CurrentRecordingTrack, recordData)
		print("[RECORDING] AnimTab event added:", name, id)
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = hum:LoadAnimation(anim)
	
	if track then
		track:Play()
		activeAnimTrack = track
		activeAnimId = id
		activeAnimBtn = btn
		
		-- UI Feedback
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		if btn:FindFirstChild("TextLabel") then
			TweenService:Create(btn.TextLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(0, 0, 0)}):Play()
		end
		
		task.spawn(function()
			track.Stopped:Wait()
			if activeAnimId == id then
				activeAnimId = nil
				activeAnimTrack = nil
				TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
				if btn:FindFirstChild("TextLabel") then
					TweenService:Create(btn.TextLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
				end
				activeAnimBtn = nil
			end
		end)
	end
end

loadAnimOrder()

for idx, data in ipairs(animGuiAnimations) do
	local btn = Instance.new("TextButton")
	btn.Name = data.n
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.LayoutOrder = data.order
	btn.Parent = animContainer

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(35, 35, 35)
	btnStroke.Thickness = 1
	btnStroke.Parent = btn

	local btnLabel = Instance.new("TextLabel")
	btnLabel.Size = UDim2.new(1, -8, 1, 0)
	btnLabel.Position = UDim2.new(0, 4, 0, 0)
	btnLabel.BackgroundTransparency = 1
	btnLabel.Text = data.n
	btnLabel.Font = Enum.Font.Gotham
	btnLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	btnLabel.TextSize = 13
	btnLabel.TextXAlignment = Enum.TextXAlignment.Center
	btnLabel.Parent = btn

	btn.MouseEnter:Connect(function()
		if activeAnimBtn ~= btn then
			TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		if activeAnimBtn ~= btn then
			TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
		end
	end)

	btn.MouseButton1Click:Connect(function()
		toggleAnimGuiEmote(data.i, data.n, btn)
	end)
end

updateAnimButtonLabels()

animToggleBtn.MouseButton1Click:Connect(function()
	isHorizontalAnim = not isHorizontalAnim
	if isHorizontalAnim then
		TweenService:Create(animMain, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 450, 0, 110)}):Play()
		animLayout.CellSize = UDim2.new(0, 94, 0, 30)
		animLayout.CellPadding = UDim2.new(0, 4, 0, 6)
	else
		TweenService:Create(animMain, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 260, 0, 214)}):Play()
		animLayout.CellSize = UDim2.new(0.48, 0, 0, 30)
		animLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	end
end)

animNumberBtn.MouseButton1Click:Connect(function()
	reorderUI.Visible = true
	for _, item in ipairs(reorderScroll:GetChildren()) do if item:IsA("Frame") then item:Destroy() end end
	local sorted = getSortedAnimGuiAnimations()
	for _, data in ipairs(sorted) do createReorderItem(data) end
end)

reorderCloseBtn.MouseButton1Click:Connect(function() reorderUI.Visible = false end)

function CharacterAdded(Character)
	for i, v in pairs(Frame:GetChildren()) do if not v:IsA("UIGridLayout") then v:Destroy() end end
	local Humanoid = WaitForChildOfClass(Character, "Humanoid")
	local Description = Humanoid:WaitForChild("HumanoidDescription", 5) or Instance.new("HumanoidDescription", Humanoid)
	local Ratio = Instance.new("UIAspectRatioConstraint")
	Ratio.AspectType = Enum.AspectType.ScaleWithParentSize
	local hideFavBtn = Instance.new("TextButton")
	hideFavBtn.Name = "HideFavoritesBtn"
	Ratio:Clone().Parent = hideFavBtn
	hideFavBtn.LayoutOrder = 0
	hideFavBtn.TextColor3 = Color3.new(1, 1, 1)
	hideFavBtn.BorderSizePixel = 0
	hideFavBtn.BackgroundTransparency = 0.3
	hideFavBtn.BackgroundColor3 = Color3.new(0, 0, 0)
	hideFavBtn.TextScaled = true
	hideFavBtn.Text = FavoritesVisible and "Hide Favorites" or "Show Favorites"
	hideFavBtn.Font = Enum.Font.GothamBold
	hideFavBtn:SetAttribute("name", "")
	Corner:Clone().Parent = hideFavBtn
	local HideFavStroke = Instance.new("UIStroke")
	HideFavStroke.Color = Color3.fromRGB(80, 80, 80)
	HideFavStroke.Thickness = 1
	HideFavStroke.Transparency = 0.5
	HideFavStroke.Parent = hideFavBtn
	hideFavBtn.MouseButton1Click:Connect(ToggleFavoriteButtons)
	hideFavBtn.MouseEnter:Connect(function() EmoteName.Text = "Toggle Favorites" end)
	hideFavBtn.Parent = Frame
	for i, Emote in pairs(Emotes) do CreateEmoteButton(Emote, Description, Ratio) end
	for i = 1, 9 do
		local EmoteButton = Instance.new("Frame")
		EmoteButton.LayoutOrder = 2147483647
		EmoteButton.Name = "filler"
		EmoteButton.BackgroundTransparency = 1
		EmoteButton.BorderSizePixel = 0
		Ratio:Clone().Parent = EmoteButton
		EmoteButton.Visible = true
		EmoteButton.Parent = Frame
	end
	
	-- Reset AnimGUI state
	activeAnimId = nil
	activeAnimTrack = nil
	if activeAnimBtn then
		activeAnimBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		if activeAnimBtn:FindFirstChild("TextLabel") then
			activeAnimBtn.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
		activeAnimBtn = nil
	end
end

if LocalPlayer.Character then CharacterAdded(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(CharacterAdded)

task.wait(5)
ScreenGui.Parent = CoreGui
