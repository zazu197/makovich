local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local incrementRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("HackingDevice")
	:WaitForChild("IncrementPlayerHealth")

if not incrementRemote:IsA("RemoteEvent") then
	return
end

RunService.PreRender:Connect(function()
	incrementRemote:FireServer(
		"::DF'LKJ[]OUDFG",
		"DSA+`FLJ~GH_=DFJG",
		"_?ADFLK~JGH&%%_KDSAFG",
		1000,
		"Q~WQW`E%R-KRQWE",
		"0?SD)JF/G#=%|HKSDGF"
	)
end)
