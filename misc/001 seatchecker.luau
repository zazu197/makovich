-- LocalScript
-- Place in StarterPlayerScripts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SEAT_KEYWORDS = {
	"001",
	"ZCA001",
	"Subliminal",
}

local SCAN_INTERVAL = 3

local trackedSeats: { [Seat | VehicleSeat]: RBXScriptConnection } = {}
local lastPrintedOccupants: { [Seat | VehicleSeat]: string } = {}

local function matches001Seat(seat: Instance): boolean
	local fullName = seat:GetFullName():lower()

	for _, keyword in SEAT_KEYWORDS do
		if fullName:find(keyword:lower(), 1, true) then
			return true
		end
	end

	return false
end

local function getOccupantName(seat: Seat | VehicleSeat): string
	local humanoid = seat.Occupant

	if not humanoid then
		return "Empty"
	end

	local character = humanoid.Parent
	if not character then
		return "Unknown"
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player.Name
	end

	return character.Name
end

local function printSeatOccupant(seat: Seat | VehicleSeat)
	local occupantName = getOccupantName(seat)

	if lastPrintedOccupants[seat] == occupantName then
		return
	end

	lastPrintedOccupants[seat] = occupantName

	print(("[001 Seat Checker] %s -> %s"):format(seat:GetFullName(), occupantName))
end

local function trackSeat(seat: Seat | VehicleSeat)
	if trackedSeats[seat] then
		return
	end

	trackedSeats[seat] = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		printSeatOccupant(seat)
	end)

	printSeatOccupant(seat)
end

local function scanFor001Seats()
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Seat") or descendant:IsA("VehicleSeat") then
			if matches001Seat(descendant) then
				trackSeat(descendant)
			end
		end
	end

	for seat, connection in trackedSeats do
		if not seat:IsDescendantOf(Workspace) then
			connection:Disconnect()
			trackedSeats[seat] = nil
			lastPrintedOccupants[seat] = nil
		end
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Seat") or descendant:IsA("VehicleSeat") then
		if matches001Seat(descendant) then
			trackSeat(descendant)
		end
	end
end)

task.spawn(function()
	while true do
		scanFor001Seats()
		task.wait(SCAN_INTERVAL)
	end
end)

scanFor001Seats()
