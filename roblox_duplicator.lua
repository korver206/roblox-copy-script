local p = game.Players.LocalPlayer
local b = p.Backpack
local duplicating = false
local savedPath = ""
local savedAmount = "1"

local function getObj(path)
    local s, o = pcall(function() return loadstring("return " .. path)() end)
    return s and o or nil
end

local function giveItem(itemPath)
    local item = getObj(itemPath)
    if item then
        local event = game:GetService("ReplicatedStorage").TS.remotes["inventory-remotes"]
        -- Assume AddItem remote, change if needed
        if event and event.AddItem then
            event.AddItem:FireServer(item)
            print("Gave: " .. item.Name)
        else
            print("AddItem remote not found")
        end
    else
        print("Item not found: " .. itemPath)
    end
end

local function dupItem(itemPath)
    giveItem(itemPath)
end

local function serializeInstance(obj)
    if not obj then return nil end
    
    local data = {
        ClassName = obj.ClassName,
        Name = obj.Name,
        Properties = {},
        Children = {}
    }
    
    -- Capture common properties based on ClassName
    if obj:IsA("BasePart") then
        local success, pos = pcall(function() return obj.Position end)
        if success then data.Properties.Position = {pos.X, pos.Y, pos.Z} end
        
        local success, size = pcall(function() return obj.Size end)
        if success then data.Properties.Size = {size.X, size.Y, size.Z} end
        
        local success, color = pcall(function() return obj.Color end)
        if success then data.Properties.Color = {color.R, color.G, color.B} end
        
        local success, mat = pcall(function() return obj.Material end)
        if success then data.Properties.Material = mat end
        
        local success, shape = pcall(function() return obj.Shape end)
        if success and shape then data.Properties.Shape = shape end
        
        local success, anchored = pcall(function() return obj.Anchored end)
        if success then data.Properties.Anchored = anchored end
        
        local success, cancollide = pcall(function() return obj.CanCollide end)
        if success then data.Properties.CanCollide = cancollide end
        
        local success, trans = pcall(function() return obj.Transparency end)
        if success then data.Properties.Transparency = trans end
    elseif obj:IsA("Model") then
        local success, primary = pcall(function() return obj.PrimaryPart end)
        if success and primary then data.Properties.PrimaryPart = primary.Name else data.Properties.PrimaryPart = nil end
    elseif obj:IsA("Script") or obj:IsA("LocalScript") then
        local success, source = pcall(function() return obj.Source end)
        if success then data.Properties.Source = source end
    end
    
    -- Recurse children
    for _, child in ipairs(obj:GetChildren()) do
        local childData = serializeInstance(child)
        if childData then
            table.insert(data.Children, childData)
        end
    end
    
    return data
end

local function serializeWorkspace()
    return serializeInstance(workspace)
end

local function generatePropertyCode(varName, prop, val)
    if type(val) == "userdata" then
        if val.Name and val.EnumType then
            return varName .. "." .. prop .. " = Enum." .. val.EnumType .. "." .. val.Name
        end
    elseif type(val) == "number" then
        return varName .. "." .. prop .. " = " .. val
    elseif type(val) == "string" then
        return varName .. "." .. prop .. " = \"" .. val:gsub("\"", "\\\""):gsub("\n", "\\n") .. "\""
    elseif type(val) == "boolean" then
        return varName .. "." .. prop .. " = " .. tostring(val)
    elseif type(val) == "table" then
        if #val == 3 and (prop == "Position" or prop == "Size") then
            return varName .. "." .. prop .. " = Vector3.new(" .. table.concat(val, ", ") .. ")"
        elseif #val == 3 and prop == "Color" then
            return varName .. "." .. prop .. " = Color3.new(" .. table.concat(val, ", ") .. ")"
        elseif #val == 4 and prop == "Size" and string.find(prop, "UDim") then
            return varName .. "." .. prop .. " = UDim2.new(" .. table.concat(val, ", ") .. ")"
        else
            local str = "{"
            for k, v in pairs(val) do
                str = str .. tostring(k) .. "=" .. tostring(v) .. ","
            end
            str = str .. "}"
            return varName .. "." .. prop .. " = " .. str
        end
    end
    return "-- Skipped property: " .. prop
end

local function generateCode(data, parentName)
    if not data then return "" end
    local code = ""
    local safeName = data.Name:gsub("[^%a%w_]", "_")
    code = code .. "local " .. safeName .. " = Instance.new(\"" .. data.ClassName .. "\")\n"
    code = code .. safeName .. ".Name = \"" .. data.Name .. "\"\n"
    for prop, val in pairs(data.Properties) do
        code = code .. generatePropertyCode(safeName, prop, val) .. "\n"
    end
    for _, childData in ipairs(data.Children) do
        code = code .. generateCode(childData, safeName)
    end
    code = code .. safeName .. ".Parent = " .. parentName .. "\n"
    return code
end

local function getFullCode()
    local serialized = serializeWorkspace()
    local code = "-- Roblox Studio Script to recreate the captured workspace\n"
    code = code .. "-- Paste this into a ServerScript in ServerScriptService or similar\n"
    code = code .. generateCode(serialized, "workspace")
    return code
end

local sg=Instance.new("ScreenGui",p.PlayerGui)
sg.Enabled=false
local f=Instance.new("Frame",sg)
f.Size=UDim2.new(0,400,0,450)
f.Position=UDim2.new(0.5,-200,0.5,-200)
f.BackgroundColor3=Color3.new(0.2,0.2,0.2)
local t=Instance.new("TextLabel",f)
t.Text="ROBLOX Islands Duplicator"
t.Size=UDim2.new(1,0,0,30)
t.BackgroundColor3=Color3.new(0.3,0.3,0.3)
local pl=Instance.new("TextLabel",f)
pl.Text="Item Path:"
pl.Size=UDim2.new(0.3,0,0,30)
pl.Position=UDim2.new(0,10,0,40)
pl.BackgroundColor3=Color3.new(0.4,0.4,0.4)
local pb=Instance.new("TextBox",f)
pb.Size=UDim2.new(0.6,0,0,30)
pb.Position=UDim2.new(0.3,10,0,40)
pb.BackgroundColor3=Color3.new(1,1,1)
pb.TextColor3=Color3.new(0,0,0)
pb.Text = savedPath
pb.FocusLost:Connect(function() savedPath = pb.Text end)
local al=Instance.new("TextLabel",f)
al.Text="Amount:"
al.Size=UDim2.new(0.3,0,0,30)
al.Position=UDim2.new(0,10,0,80)
al.BackgroundColor3=Color3.new(0.4,0.4,0.4)
local ab=Instance.new("TextBox",f)
ab.Size=UDim2.new(0.6,0,0,30)
ab.Position=UDim2.new(0.3,10,0,80)
ab.BackgroundColor3=Color3.new(1,1,1)
ab.TextColor3=Color3.new(0,0,0)
ab.Text = savedAmount
ab.FocusLost:Connect(function() savedAmount = ab.Text end)
local gb=Instance.new("TextButton",f)
gb.Text="Give"
gb.Size=UDim2.new(0.45,0,0,30)
gb.Position=UDim2.new(0,10,0,120)
gb.BackgroundColor3=Color3.new(0.5,0.5,0.5)
gb.MouseButton1Click:Connect(function()
    local itemPath=pb.Text
    local amt=tonumber(ab.Text)or 1
    if itemPath~=""and not duplicating then
        duplicating=true
        for i=1,amt do giveItem(itemPath)wait(math.random(1,3))end
        duplicating=false
    end
end)
local db=Instance.new("TextButton",f)
db.Text="Duplicate"
db.Size=UDim2.new(0.45,0,0,30)
db.Position=UDim2.new(0.5,10,0,120)
db.BackgroundColor3=Color3.new(0.5,0.5,0.5)
db.MouseButton1Click:Connect(function()
    local itemPath=pb.Text
    local amt=tonumber(ab.Text)or 1
    if itemPath~=""and not duplicating then
        duplicating=true
        for i=1,amt do dupItem(itemPath)wait(math.random(1,3))end
        duplicating=false
    end
end)

local outputBox=Instance.new("TextBox",f)
outputBox.Name="OutputBox"
outputBox.Size=UDim2.new(1,0,0,150)
outputBox.Position=UDim2.new(0,0,0,160)
outputBox.BackgroundColor3=Color3.new(0.15,0.15,0.15)
outputBox.BorderSizePixel=0
outputBox.TextColor3=Color3.new(1,1,1)
outputBox.Text="Generated code will appear here. Copy and paste into a Roblox Studio script."
outputBox.MultiLine=true
outputBox.TextWrapped=true
outputBox.ClearTextOnFocus=false
outputBox.TextXAlignment=Enum.TextXAlignment.Left
outputBox.TextYAlignment=Enum.TextYAlignment.Top
outputBox.Font=Enum.Font.Code
outputBox.TextSize=10

local copyb=Instance.new("TextButton",f)
copyb.Text="Copy Game Structure"
copyb.Size=UDim2.new(1,0,0,30)
copyb.Position=UDim2.new(0,0,0,320)
copyb.BackgroundColor3=Color3.new(0,0.7,0)
copyb.TextColor3=Color3.new(1,1,1)
copyb.Font=Enum.Font.SourceSansBold
copyb.MouseButton1Click:Connect(function()
    if not duplicating then
        duplicating=true
        print("Starting game structure copy...")
        local success, code = pcall(getFullCode)
        if success then
            outputBox.Text = code
            print("Game structure code generated successfully!")
        else
            outputBox.Text = "-- Error generating code: " .. tostring(code)
            print("Error in generation: " .. tostring(code))
        end
        duplicating=false
    else
        print("Already duplicating, please wait.")
    end
end)

local clipb=Instance.new("TextButton",f)
clipb.Text="Copy to Clipboard"
clipb.Size=UDim2.new(1,0,0,30)
clipb.Position=UDim2.new(0,0,0,360)
clipb.BackgroundColor3=Color3.new(0.2,0.5,0.8)
clipb.TextColor3=Color3.new(1,1,1)
clipb.Font=Enum.Font.SourceSansBold
clipb.MouseButton1Click:Connect(function()
    if outputBox.Text ~= "Generated code will appear here. Copy and paste into a Roblox Studio script." then
        setclipboard(outputBox.Text)
        print("Code copied to clipboard!")
    else
        print("No code generated yet. Click 'Copy Game Structure' first.")
    end
end)

local cb=Instance.new("TextButton",f)
cb.Text="Close"
cb.Size=UDim2.new(1,0,0,30)
cb.Position=UDim2.new(0,0,0,390)
cb.BackgroundColor3=Color3.new(0.6,0.6,0.6)
cb.MouseButton1Click:Connect(function()sg.Enabled=false end)
game:GetService("UserInputService").InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.G then
        sg.Enabled=not sg.Enabled
    end
end)
print("GUI loaded. Press G to toggle.")