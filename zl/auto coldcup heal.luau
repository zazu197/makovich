local active = true

while active do
	task.wait(0.01) --cahange yo your desired coooldown 0.01 maybe laggy idk 
	local Event = game:GetService("ReplicatedStorage").Remotes.PlasticCupDrink
    Event:FireServer()
end
