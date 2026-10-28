
local Database = {}

local config = YRM.Config and YRM.Config.Database

if type(config) ~= "table" then
    error("[YRM] Configuration Database absente. Vérifie le chargement de Shared/Config.lua.")
end

local databaseType = string.lower(config.Type or "sqlite")

local Drivers = {
    sqlite = "SQLite.lua",
    mysql = "MySQL.lua"
}

local driverFile = Drivers[databaseType]

if not driverFile then
    error("[YRM] Moteur de base de données inconnu : "
        .. tostring(databaseType))
end

local Driver = Package.Require("Server/Database/" .. driverFile)

if type(Driver) ~= "table" then
    error("[YRM] Le driver " .. databaseType
        .. " n'a pas retourné de module valide.")
end

Database.Driver = Driver
Database.Type = databaseType
Database.Ready = false

function Database.Connect()
    if Database.IsConnected() then
        Database.Ready = true
        return true
    end

    if type(Driver.Connect) ~= "function" then
        return false, "Le driver ne fournit pas Connect()."
    end

    local driverConfig = config[
        databaseType == "sqlite" and "SQLite" or "MySQL"
    ]

    if type(driverConfig) ~= "table" then
        return false, "Configuration absente pour " .. databaseType .. "."
    end

    local called, success, err = pcall(Driver.Connect, driverConfig)

    if not called then
        Database.Ready = false
        return false, tostring(success)
    end

    if success ~= true then
        Database.Ready = false
        return false, err or "Échec de connexion à la base de données."
    end

    Database.Ready = true
    print("[YRM] Base de données connectée (" .. databaseType .. ").")

    return true
end

function Database.IsConnected()
    return Driver.Connected == true
end

local function ValidateQuery(query)
    if not Database.IsConnected() then
        return false, "La base de données n'est pas connectée."
    end

    if type(query) ~= "string" or query:match("^%s*$") then
        return false, "Requête SQL invalide."
    end

    return true
end

function Database.Execute(query, ...)
    local valid, validationError = ValidateQuery(query)

    if not valid then
        return nil, validationError
    end

    if type(Driver.Execute) ~= "function" then
        return nil, "Le driver ne fournit pas Execute()."
    end

    local called, result, err = pcall(Driver.Execute, query, ...)

    if not called then
        return nil, tostring(result)
    end

    if result == nil then
        return nil, err or "Échec de l'exécution SQL."
    end

    return result, err
end

function Database.Select(query, ...)
    local valid, validationError = ValidateQuery(query)

    if not valid then
        return nil, validationError
    end

    if type(Driver.Select) ~= "function" then
        return nil, "Le driver ne fournit pas Select()."
    end

    local called, rows, err = pcall(Driver.Select, query, ...)

    if not called then
        return nil, tostring(rows)
    end

    if rows == nil then
        return nil, err or "Échec de la lecture SQL."
    end

    return rows, err
end

function Database.Insert(query, ...)
    return Database.Execute(query, ...)
end

function Database.Close()
    if type(Driver.Close) ~= "function" then
        Database.Ready = false
        return true
    end

    local called, success, err = pcall(Driver.Close)

    Database.Ready = false

    if not called then
        return false, tostring(success)
    end

    if success == false then
        return false, err or "Impossible de fermer la connexion."
    end

    print("[YRM] Connexion à la base de données fermée.")
    return true
end

-- Retourne une date selon le décalage UTC configuré.
-- Exemple : UTCOffset = 2 => UTC+2.
function Database.GetDateTime()
    local offset = tonumber(config.UTCOffset) or 0

    if offset < -12 or offset > 14 then
        return nil, "Décalage UTC invalide."
    end

    local utcTable = os.date("!*t")
    local utcTimestamp = os.time(utcTable)
    local adjustedTimestamp = utcTimestamp + math.floor(offset * 3600)

    return os.date("!%Y-%m-%d %H:%M:%S", adjustedTimestamp)
end

YRM.Database = Database

return Database
