local GatesFolder = workspace.Facility.Sectors["Zeta Labs"].Interactions.Doors.LockdownGates
local Descendants = GatesFolder:GetDescendants()

for _, item in Descendants do
    if item:IsA("Model") and item.Name == "LockdownGate" then
        if item:GetAttribute("Active") == true then
            print(item:GetPivot() )
            print("Gate is active")
        end
    end
end

