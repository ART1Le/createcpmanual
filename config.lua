-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Executor API detection
local _writefile = writefile or (syn and syn.writefile) or function() warn("writefile not available") end
local _readfile = readfile or (syn and syn.readfile) or function() warn("readfile not available"); return nil end
local _setclipboard = setclipboard or toclipboard or function(text) print("[COPY]",text) end

-- Paths
local ROOT_DIR = "" -- root executor
local DEFAULT_FILE = "checkpoints.json"

-- State
local State = {fileName=DEFAULT_FILE, checkpoints={}, previewFor=nil}
local previewParts = {} -- for all preview

-- Helpers
local function getCharacter() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function getHRP() return getCharacter():WaitForChild("HumanoidRootPart") end
local function newId() return tostring(os.time()).."-"..tostring(math.random(100000,999999)) end

-- Add/Remove checkpoint
local function addCheckpoint(name)
    local hrp = getHRP()
    if not hrp then warn("No HRP") return end
    name = (name and name~="") and name or ("CP "..(#State.checkpoints+1))
    table.insert(State.checkpoints,{id=newId(), name=name, cf=hrp.CFrame})
end
local function removeCheckpoint(id)
    for i,cp in ipairs(State.checkpoints) do
        if cp.id==id then table.remove(State.checkpoints,i); if State.previewFor==id then State.previewFor=nil end return end
    end
end

-- Teleport/Copy
local function teleportTo(cp)
    local hrp = getHRP()
    if hrp then hrp.CFrame = cp.cf end
end
local function copyPos(cp)
    local p = cp.cf.Position
    local str = string.format("{ x=%.3f, y=%.3f, z=%.3f }", p.X,p.Y,p.Z)
    pcall(function() _setclipboard(str) end)
end

-- Save/Load JSON
local function saveToFileReliable(tbl, fileName)
    local data = {checkpoints={}}
    for _,cp in ipairs(tbl) do
        local p = cp.cf.Position
        table.insert(data.checkpoints,{id=cp.id,name=cp.name,pos={x=p.X,y=p.Y,z=p.Z}})
    end
    local path = (ROOT_DIR~="" and ROOT_DIR.."/" or "")..(fileName or DEFAULT_FILE)
    local ok, err = pcall(function() _writefile(path,HttpService:JSONEncode(data)) end)
    return ok, ok and path or err
end
local function loadFromFileReliable(fileName)
    local path = (ROOT_DIR~="" and ROOT_DIR.."/" or "")..(fileName or DEFAULT_FILE)
    local ok, content = pcall(function() return _readfile(path) end)
    if not ok or not content then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(data.checkpoints)~="table" then return false end
    local arr={}
    for _,cp in ipairs(data.checkpoints) do
        local pos=cp.pos
        if pos then table.insert(arr,{id=cp.id or newId(),name=cp.name or "CP",cf=CFrame.new(pos.x,pos.y,pos.z)}) end
    end
    State.checkpoints=arr
    rebuildList()
    rebuildPreviewParts()
    return true
end

-- Preview all checkpoints
local function rebuildPreviewParts()
    -- Clear old parts
    for _,p in ipairs(previewParts) do if p and p.Parent then p:Destroy() end end
    previewParts = {}
    for _,cp in ipairs(State.checkpoints) do
        local part = Instance.new("Part")
        part.Name = "CP_Preview_"..cp.id
        part.Size = Vector3.new(2,2,2)
        part.Shape = Enum.PartType.Ball
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = (State.previewFor==cp.id) and Color3.fromRGB(0,255,136) or Color3.fromRGB(255,200,50)
        part.Transparency = 0.25
        part.CFrame = cp.cf
        part.Parent = workspace
        table.insert(previewParts,part)
    end
end

-- Continuously update preview positions
RunService.Heartbeat:Connect(function()
    for i,cp in ipairs(State.checkpoints) do
        if previewParts[i] and previewParts[i].Parent then
            previewParts[i].CFrame = cp.cf
            previewParts[i].Color = (State.previewFor==cp.id) and Color3.fromRGB(0,255,136) or Color3.fromRGB(255,200,50)
        end
    end
end)

-- GUI
local function protectGui(gui) if syn and syn.protect_gui then pcall(syn.protect_gui,gui) end; gui.Parent=gethui and gethui() or game:GetService("CoreGui") end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name="CheckpointManager"
ScreenGui.ResetOnSpawn=false
protectGui(ScreenGui)

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,480,0,360)
Main.Position=UDim2.new(0,60,0,60)
Main.BackgroundColor3=Color3.fromRGB(30,30,35)
Main.BorderSizePixel=0
Main.Active=true
Main.Draggable=true
Main.Parent=ScreenGui
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)

local Header = Instance.new("TextLabel")
Header.Size=UDim2.new(1,0,0,36)
Header.BackgroundColor3=Color3.fromRGB(40,40,48)
Header.BorderSizePixel=0
Header.Font=Enum.Font.GothamBold
Header.TextSize=16
Header.TextColor3=Color3.new(1,1,1)
Header.Text="Checkpoint Manager"
Header.Parent=Main

local function mkButton(t,size,pos)
    local b=Instance.new("TextButton")
    b.Size = size
    if pos then b.Position=pos end
    b.BackgroundColor3 = Color3.fromRGB(60,60,70)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.TextColor3 = Color3.new(1,1,1)
    b.Text=t
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    return b
end

local FileBox = Instance.new("TextBox")
FileBox.Size=UDim2.new(0,190,0,28)
FileBox.Position=UDim2.new(0,10,0,44)
FileBox.Text=DEFAULT_FILE
FileBox.PlaceholderText="nama file .json"
FileBox.BackgroundColor3=Color3.fromRGB(50,50,58)
FileBox.TextColor3=Color3.new(1,1,1)
FileBox.ClearTextOnFocus=false
FileBox.Font=Enum.Font.Gotham
FileBox.TextSize=14
Instance.new("UICorner",FileBox).CornerRadius=UDim.new(0,6)
FileBox.Parent=Main

-- Buttons
local SaveBtn = mkButton("Save File",UDim2.new(0,80,0,28),UDim2.new(0,244,0,44)); SaveBtn.Parent=Main
local LoadBtn = mkButton("Load File",UDim2.new(0,80,0,28),UDim2.new(0,328,0,44)); LoadBtn.Parent=Main
local CopyJsonBtn = mkButton("Copy JSON",UDim2.new(0,68,0,28),UDim2.new(0,412,0,44)); CopyJsonBtn.Parent=Main
local AddBtn = mkButton("Add Checkpoint",UDim2.new(0,180,0,28),UDim2.new(0,10,0,80)); AddBtn.Parent=Main

local List = Instance.new("ScrollingFrame")
List.Size=UDim2.new(1,-20,1,-120)
List.Position=UDim2.new(0,10,0,116)
List.BackgroundColor3=Color3.fromRGB(36,36,42)
List.BorderSizePixel=0
List.ScrollBarThickness=6
List.Parent=Main
local UIListLayout=Instance.new("UIListLayout",List)
UIListLayout.Padding=UDim.new(0,6)
UIListLayout.SortOrder=Enum.SortOrder.LayoutOrder
UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() List.CanvasSize=UDim2.new(0,0,0,UIListLayout.AbsoluteContentSize.Y+10) end)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size=UDim2.new(1,-20,0,22)
StatusLabel.Position=UDim2.new(0,10,1,-26)
StatusLabel.BackgroundTransparency=1
StatusLabel.Font=Enum.Font.Gotham
StatusLabel.TextSize=12
StatusLabel.TextXAlignment=Enum.TextXAlignment.Left
StatusLabel.TextColor3=Color3.fromRGB(200,200,210)
StatusLabel.Text="Root executor"
StatusLabel.Parent=Main
local function setStatus(msg,kind)
    StatusLabel.Text=msg
    if kind=="ok" then StatusLabel.TextColor3=Color3.fromRGB(80,220,130)
    elseif kind=="err" then StatusLabel.TextColor3=Color3.fromRGB(235,100,100)
    else StatusLabel.TextColor3=Color3.fromRGB(200,200,210) end
end

-- Build row
function mkRow(cp,index)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-10,0,40)
    row.BackgroundColor3 = Color3.fromRGB(46,46,54)
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5,0,1,0)
    lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local p = cp.cf.Position
    lbl.Text = string.format("%d. %s (%.1f,%.1f,%.1f)",index,cp.name,p.X,p.Y,p.Z)
    lbl.TextColor3 = Color3.fromRGB(235,235,240)
    lbl.Parent = row

    local btnHolder = Instance.new("Frame")
    btnHolder.Size = UDim2.new(0.5,-10,1,0)
    btnHolder.Position = UDim2.new(0.5,0,0,0)
    btnHolder.BackgroundTransparency = 1
    btnHolder.Parent = row
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0,4)
    layout.Parent = btnHolder

    local function addBtn(txt)
        local b = mkButton(txt,UDim2.new(0,28,0,28))
        b.Parent = btnHolder
        return b
    end

    local previewBtn = addBtn("👁️")
    previewBtn.MouseButton1Click:Connect(function()
        if State.previewFor==cp.id then State.previewFor=nil else State.previewFor=cp.id end
    end)
    local copyBtn = addBtn("📋"); copyBtn.MouseButton1Click:Connect(function() copyPos(cp) end)
    local tpBtn = addBtn("🚀"); tpBtn.MouseButton1Click:Connect(function() teleportTo(cp) end)
    local delBtn = addBtn("🗑️"); delBtn.MouseButton1Click:Connect(function() removeCheckpoint(cp.id); rebuildList(); rebuildPreviewParts(); setStatus("Removed "..cp.name,"ok") end)

    return row
end

-- Rebuild list
function rebuildList()
    for _,c in ipairs(List:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
    for i,cp in ipairs(State.checkpoints) do mkRow(cp,i).Parent=List end
    rebuildPreviewParts()
end

-- Button hooks
AddBtn.MouseButton1Click:Connect(function() addCheckpoint(); rebuildList(); setStatus("Added checkpoint","ok") end)
SaveBtn.MouseButton1Click:Connect(function()
    local fname = (FileBox.Text~="" and FileBox.Text or DEFAULT_FILE)
    if not fname:lower():match("%.json$") then fname=fname..".json" end
    State.fileName=fname
    local ok,path=saveToFileReliable(State.checkpoints,fname)
    if ok then setStatus("Saved: "..tostring(path),"ok") else setStatus("Save failed","err") end
end)
LoadBtn.MouseButton1Click:Connect(function()
    local fname = (FileBox.Text~="" and FileBox.Text or DEFAULT_FILE)
    State.fileName=fname
    local ok=loadFromFileReliable(fname)
    if ok then setStatus("Loaded ("..tostring(#State.checkpoints)..")","ok") else setStatus("Load failed","err") end
end)
CopyJsonBtn.MouseButton1Click:Connect(function()
    local data={checkpoints={}}
    for _,cp in ipairs(State.checkpoints) do
        local p = cp.cf.Position
        table.insert(data.checkpoints,{id=cp.id,name=cp.name,pos={x=p.X,y=p.Y,z=p.Z}})
    end
    pcall(function() _setclipboard(HttpService:JSONEncode(data)) end)
    setStatus("JSON copied to clipboard","ok")
end)

-- Toggle GUI
UserInputService.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.KeyCode==Enum.KeyCode.RightAlt then ScreenGui.Enabled=not ScreenGui.Enabled end
end)

-- Initial
rebuildList()
