
local Players = {}

Players.Data = {}
Players.PendingData = {}

local function GetSteamID(player)
    if not player or type(player.GetSteamID) ~= "function" then
        return nil, "Joueur invalide."
    end

    local steamID = player:GetSteamID()

    if not steamID or steamID == "" then
        return nil, "Steam ID indisponible."
    end

    return tostring(steamID)
end

local function GetDateTime()
    if not YRM.Database
        or type(YRM.Database.GetDateTime) ~= "function" then
        return nil, "Fonction de date Database indisponible."
    end

    return YRM.Database.GetDateTime()
end

local function EncodeData(data)
    if not JSON or type(JSON.stringify) ~= "function" then
        return nil, "JSON.stringify indisponible."
    end

    local success, result = pcall(JSON.stringify, data)

    if not success or type(result) ~= "string" then
        return nil, "Impossible d'encoder les données du joueur."
    end

    return result
end

local function DecodeData(value)
    if not value or value == "" then
        return {}
    end

    if not JSON or type(JSON.parse) ~= "function" then
        return nil, "JSON.parse indisponible."
    end

    local success, result = pcall(JSON.parse, value)

    if not success or type(result) ~= "table" then
        return nil, "Impossible de décoder les données du joueur."
    end

    return result
end

-- PROFIL PRINCIPAL

function Players.SaveBySteamID(steamID)
    if not steamID or steamID == "" then
        return false, "Steam ID invalide."
    end

    steamID = tostring(steamID)

    local dateTime, dateError = GetDateTime()
    if not dateTime then
        return false, dateError
    end

    local rows, selectError = YRM.Database.Select(
        "SELECT steam_id FROM yrm_players WHERE steam_id = :0",
        steamID
    )

    if rows == nil then
        return false, selectError or "Erreur de lecture du profil."
    end

    local result, err

    if #rows == 0 then
        result, err = YRM.Database.Execute([[
            INSERT INTO yrm_players
                (steam_id, created_at, last_seen, data)
            VALUES (:0, :1, :1, :2)
        ]], steamID, dateTime, "{}")
    else
        result, err = YRM.Database.Execute([[
            UPDATE yrm_players
            SET last_seen = :0
            WHERE steam_id = :1
        ]], dateTime, steamID)
    end

    if result == nil then
        return false, err or "Erreur SQL lors de la sauvegarde."
    end

    return true
end

function Players.Save(player)
    local steamID, err = GetSteamID(player)

    if not steamID then
        return false, err
    end

    return Players.SaveBySteamID(steamID)
end

-- CHARGEMENT DES DONNÉES

function Players.LoadData(steamID)
    steamID = tostring(steamID or "")

    if steamID == "" then
        return false, "Steam ID invalide."
    end

    -- Évite d'écraser des modifications encore en attente.
    if Players.Data[steamID] then
        return true, Players.Data[steamID]
    end

    local rows, err = YRM.Database.Select([[
        SELECT data
        FROM yrm_players
        WHERE steam_id = :0
    ]], steamID)

    if rows == nil then
        return false, err or "Impossible de charger les données."
    end

    if #rows == 0 then
        local saved, saveError = Players.SaveBySteamID(steamID)

        if not saved then
            return false, saveError
        end

        rows, err = YRM.Database.Select([[
            SELECT data
            FROM yrm_players
            WHERE steam_id = :0
        ]], steamID)

        if rows == nil or #rows == 0 then
            return false, err or "Profil introuvable après création."
        end
    end

    local data, decodeError = DecodeData(rows[1].data)

    if not data then
        return false, decodeError
    end

    Players.Data[steamID] = data
    Players.PendingData[steamID] = {}

    return true, data
end

-- LECTURE

function Players.GetData(steamID, key, defaultValue)
    steamID = tostring(steamID or "")

    local data = Players.Data[steamID]

    if data and data[key] ~= nil then
        return data[key]
    end

    return defaultValue
end

-- MODIFICATION

function Players.SetData(steamID, key, value)
    steamID = tostring(steamID or "")

    if steamID == "" then
        return false, "Steam ID invalide."
    end

    if type(key) ~= "string" or key == "" then
        return false, "Clé invalide."
    end

    if value ~= nil
        and type(value) ~= "string"
        and type(value) ~= "number"
        and type(value) ~= "boolean" then
        return false, "Type de donnée non accepté."
    end

    if not Players.Data[steamID] then
        return false, "Données non chargées. Appelle LoadData avant SetData."
    end

    Players.PendingData[steamID] =
        Players.PendingData[steamID] or {}

    Players.PendingData[steamID][key] = {
        Value = value,
        Deleted = value == nil
    }

    Players.Data[steamID][key] = value

    if not YRM.Persistence then
        return false, "Persistence n'est pas chargé."
    end

    return YRM.Persistence.MarkDirty(
        "players",
        steamID,
        function(id)
            return Players.SaveData(id)
        end
    )
end

-- SAUVEGARDE DES DONNÉES

function Players.SaveData(steamID)
    steamID = tostring(steamID or "")

    local pending = Players.PendingData[steamID]

    if not pending or not next(pending) then
        return true
    end

    local data = Players.Data[steamID]

    if not data then
        return false, "Données du joueur non chargées."
    end

    -- Copie de la file pour préserver les changements intervenus
    -- pendant la sauvegarde.
    local snapshot = {}

    for key, change in pairs(pending) do
        snapshot[key] = {
            Value = change.Value,
            Deleted = change.Deleted
        }
    end

    local encoded, encodeError = EncodeData(data)

    if not encoded then
        return false, encodeError
    end

    local dateTime, dateError = GetDateTime()

    if not dateTime then
        return false, dateError
    end

    local result, err = YRM.Database.Execute([[
        UPDATE yrm_players
        SET data = :0, last_seen = :1
        WHERE steam_id = :2
    ]], encoded, dateTime, steamID)

    if result == nil then
        return false, err or "Échec de sauvegarde des données."
    end

    local current = Players.PendingData[steamID]

    if current then
        for key, oldChange in pairs(snapshot) do
            local now = current[key]

            if now
                and now.Deleted == oldChange.Deleted
                and now.Value == oldChange.Value then
                current[key] = nil
            end
        end

        if not next(current) then
            Players.PendingData[steamID] = nil
        end
    end

    return true
end

-- SAUVEGARDE COMPLÈTE

function Players.SaveAll(steamID)
    steamID = tostring(steamID or "")

    local success, err = Players.SaveBySteamID(steamID)

    if not success then
        return false, err
    end

    return Players.SaveData(steamID)
end

return Players
