YRM = YRM or {}
YRM.Config = YRM.Config or {}
YRM.Commands = YRM.Commands or {}

Package.Require("Shared/Index.lua")

local function GetCommandPrefix()
    return YRM.Config.CommandPrefix or "/"
end


function YRM.RegisterCommand(name, data)
    assert(type(name) == "string", "YRM: name must be a string")
    assert(type(data) == "table", "YRM: data must be a table")
    assert(
        type(data.OnExecute) == "function",
        "YRM: OnExecute must be a function"
    )

    name = string.lower(name)

    assert(name:match("^[%w_-]+$"), "YRM: invalid command name")

    if YRM.Commands[name] then
        Console.Warn("YRM: Command already registered: " .. name)
        return false
    end

    YRM.Commands[name] = {
        Name = name,
        Description = data.Description or "",
        Permission = data.Permission,
        OnExecute = data.OnExecute
    }

    Console.Log("YRM: Registered command: " .. name)

    return true
end


function YRM.GetCommand(name)
    if type(name) ~= "string" then
        return nil
    end

    return YRM.Commands[string.lower(name)]
end

-- ID du joueur tel qu'il est utilisé par les commandes :
--   YRM.Config.UniqueID.Enabled = true  -> ID unique (base de données)
--   YRM.Config.UniqueID.Enabled = false -> ID natif Nanos World
-- C'est le seul endroit où cette décision est prise pour les commandes.
function YRM.GetCommandID(player)
    if not player or type(player.GetID) ~= "function" then
        return nil, "Joueur invalide."
    end

    if YRM.Config.UniqueID and YRM.Config.UniqueID.Enabled == true then
        return YRM.GetUniqueID(player)
    end

    return player:GetID()
end

function YRM.FindPlayerByID(id)
    if id == nil then
        return nil, "ID joueur manquant."
    end

    id = tonumber(id)

    if not id or id < 1 or id % 1 ~= 0 then
        return nil, "ID joueur invalide."
    end

    for _, player in pairs(Player.GetAll()) do
        if tonumber(YRM.GetCommandID(player)) == id then
            return player
        end
    end

    return nil, "Aucun joueur connecté ne possède cet ID."
end

Chat.Subscribe("PlayerSubmit", function(message, player)
    if type(message) ~= "string" then
        return true
    end

    local prefix = GetCommandPrefix()

    if message:sub(1, #prefix) ~= prefix then
        return true
    end

    local input = message:sub(#prefix + 1)
    local args = {}

    for arg in input:gmatch("%S+") do
        args[#args + 1] = arg
    end

    local name = args[1]

    if not name then
        return false
    end

    table.remove(args, 1)

    local command = YRM.GetCommand(name)

    -- Laisser les messages inconnus dans le chat
    if not command then
        return true
    end

    local success, err = pcall(function()
        command.OnExecute(player, args)
    end)

    if not success then
        Console.Error(
            "YRM command '" .. name .. "' failed: " .. tostring(err)
        )
    end

    return false
end)