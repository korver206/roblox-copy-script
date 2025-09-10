local p = game.Players.LocalPlayer
local duplicating = false


local function captureProperties(obj, data)
    if obj:IsA("BasePart") then
        local success, pos = pcall(function() return obj.Position end)
        if success then data.Properties.Position = {pos.X, pos.Y, pos.Z} end
        
        local success, size = pcall(function() return obj.Size end)
        if success then data.Properties.Size = {size.X, size.Y, size.Z} end
        
        local success, color = pcall(function() return obj.Color end)
        if success then data.Properties.Color = {color.R, color.G, color.B} end
        
        local success, mat = pcall(function() return obj.Material.Name end)
        if success then data.Properties.Material = mat end
        
        local success, shape = pcall(function() return obj.Shape.Name end)
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
end

local function serializeWorkspace()
    local rootData = {
        ClassName = workspace.ClassName,
        Name = workspace.Name,
        Properties = {},
        Children = {}
    }
    captureProperties(workspace, rootData)
    
    local stack = {workspace}
    local childMap = {[workspace] = rootData.Children}
    local processedCount = 0
    while #stack > 0 do
        local obj = table.remove(stack)
        processedCount = processedCount + 1
        if processedCount % 100 == 0 then
            print("Processed " .. processedCount .. " instances...")
        end
        for _, child in ipairs(obj:GetChildren()) do
            local childData = {
                ClassName = child.ClassName,
                Name = child.Name,
                Properties = {},
                Children = {}
            }
            captureProperties(child, childData)
            table.insert(childMap[obj], childData)
            table.insert(stack, child)
            childMap[child] = childData.Children
        end
    end
    print("Serialization complete. Processed " .. processedCount .. " instances.")
    return rootData
end


local function generatePropertyCode(varName, prop, val)
    if type(val) == "string" and (prop == "Material" or prop == "Shape") then
        return varName .. "." .. prop .. " = Enum." .. prop .. "." .. val
    elseif type(val) == "userdata" then
        if val.Name and val.EnumType then
            return varName .. "." .. prop .. " = Enum." .. val.EnumType.Name .. "." .. val.Name
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
f.Size=UDim2.new(0,400,0,350)
f.Position=UDim2.new(0.5,-200,0.5,-200)
f.BackgroundColor3=Color3.new(0.2,0.2,0.2)
local t=Instance.new("TextLabel",f)
t.Text="Roblox Game Copier"
t.Size=UDim2.new(1,0,0,30)
t.BackgroundColor3=Color3.new(0.3,0.3,0.3)

local statusLabel = Instance.new("TextLabel", f)
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 30)
statusLabel.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.Text = "Ready"
statusLabel.TextWrapped = true
local outputBox=Instance.new("TextBox",f)
outputBox.Name="OutputBox"
outputBox.Size=UDim2.new(1,0,0,150)
outputBox.Position=UDim2.new(0,0,0,50)
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
copyb.Position=UDim2.new(0,0,0,220)
copyb.BackgroundColor3=Color3.new(0,0.7,0)
copyb.TextColor3=Color3.new(1,1,1)
copyb.Font=Enum.Font.SourceSansBold
copyb.MouseButton1Click:Connect(function()
    if not duplicating then
        duplicating = true
        statusLabel.Text = "Starting serialization..."
        print("Starting game structure copy...")
        print("Spawn started")
        spawn(function()
            print("Inside spawn")
            local success, code = pcall(function()
                print("Inside pcall getFullCode")
                return getFullCode()
            end)
            if success then
                outputBox.Text = code
                statusLabel.Text = "Generation complete!"
                print("Game structure code generated successfully!")
            else
                outputBox.Text = "-- Error generating code: " .. tostring(code)
                statusLabel.Text = "Error: " .. tostring(code)
                print("Error in generation: " .. tostring(code))
            end
            duplicating = false
        end)
    else
        print("Already duplicating, please wait.")
    end
end)

local clipb=Instance.new("TextButton",f)
clipb.Text="Copy to Clipboard"
clipb.Size=UDim2.new(1,0,0,30)
clipb.Position=UDim2.new(0,0,0,260)
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
cb.Position=UDim2.new(0,0,0,300)
cb.BackgroundColor3=Color3.new(0.6,0.6,0.6)
cb.MouseButton1Click:Connect(function()sg.Enabled=false end)
game:GetService("UserInputService").InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.G then
        sg.Enabled=not sg.Enabled
    end
end)
print("GUI loaded. Press G to toggle.")