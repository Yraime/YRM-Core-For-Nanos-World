YRM = YRM or {}
YRM.Config = YRM.Config or {}

Package.Require("Shared/Index.lua")

local UniqueID = {}

-- Source de vérité : YRM.Config.UniqueID.Enabled (lu à chaque appel,
-- donc indépendant de l'ordre de chargement des fichiers).
local function IsEnabled()
    return YRM.Config.UniqueID ~= nil
        and YRM.Config.UniqueID.Enabled == true
end

-- Cache : ID natif Nanos World -> ID unique (évite une requête SQL à chaque appel)
local cache = {}

local function GetSteamID(player)
    if not player or type(player.GetSteamID) ~= "function" then
        return nil, "Joueur invalide."
    end

    local steamID = player:GetSteamID()

    if not steamID or tostring(steamID) == "" then
        return nil, "Steam ID indisponible."
    end

    return tostring(steamID)
end

function UniqueID.GetBySteamID(steamID)
    if not IsEnabled() then
        return nil, "Le système UniqueID est désactivé."
    end

    if steamID == nil or tostring(steamID) == "" then
        return nil, "Steam ID invalide."
    end

    local rows, err = YRM.Database.Select(
        "SELECT id FROM yrm_players WHERE steam_id = :0",
        tostring(steamID)
    )

    if not rows then
        return nil, err or "Erreur lors de la recherche du joueur."
    end

    if #rows == 0 then
        return nil, "Joueur introuvable dans la base de données."
    end

    return tonumber(rows[1].id)
end

function UniqueID.Get(player)
    if not IsEnabled() then
        return nil, "Le système UniqueID est désactivé."
    end

    local steamID, err = GetSteamID(player)

    if not steamID then
        return nil, err
    end

    local nativeID = player:GetID()

    if cache[nativeID] then
        return cache[nativeID]
    end

    local uniqueID, dbErr = UniqueID.GetBySteamID(steamID)

    if uniqueID then
        cache[nativeID] = uniqueID -- on ne met jamais nil en cache
    end

    return uniqueID, dbErr
end

function UniqueID.ClearCache(player)
    if player and type(player.GetID) == "function" then
        cache[player:GetID()] = nil
    end
end

-- Libère le cache quand un joueur part (l'ID natif peut être réattribué)
Player.Subscribe("Destroy", function(player)
    UniqueID.ClearCache(player)
end)

YRM.UniqueID = UniqueID

-- ID unique d'un joueur.
-- Activé    -> ID unique (base de données)
-- Désactivé -> ID natif Nanos World
function YRM.GetUniqueID(player)
    if not player or type(player.GetID) ~= "function" then
        return nil, "Joueur invalide."
    end

    if IsEnabled() then
        return UniqueID.Get(player)
    end

    return player:GetID()
end

return UniqueID