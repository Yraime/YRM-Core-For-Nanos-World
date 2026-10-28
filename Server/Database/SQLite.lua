
local SQLite = {}

SQLite.Connected = false
SQLite.Connection = nil

-- Initialise la connexion SQLite.
-- Le fichier est créé automatiquement par nanos world
-- s'il n'existe pas encore.
function SQLite.Connect(config)
    if SQLite.Connected then
        print("[YRM] SQLite est déjà connecté.")
        return true
    end

    config = config or {}

    local path = config.Path or "yrm_core.db"
    local connectionString = "db=" .. path .. " timeout=2"

    local success, connection = pcall(function()
        return Database(
            DatabaseEngine.SQLite,
            connectionString
        )
    end)

    if not success or not connection then
        SQLite.Connection = nil
        SQLite.Connected = false

        local err = tostring(connection or "Erreur inconnue")
        print("[YRM] Impossible de connecter SQLite : " .. err)

        return false, err
    end

    SQLite.Connection = connection
    SQLite.Connected = true

    print("[YRM] SQLite connecté : " .. path)

    return true
end

-- Exécute une requête SQL qui ne retourne pas de lignes.
-- Exemple : CREATE TABLE, INSERT, UPDATE, DELETE.
function SQLite.Execute(query, ...)
    if not SQLite.Connected or not SQLite.Connection then
        return nil, "SQLite n'est pas connecté."
    end

    if type(query) ~= "string" or query == "" then
        return nil, "Requête SQL invalide."
    end

    local affectedRows, err =
        SQLite.Connection:Execute(query, ...)

    if err then
        print("[YRM] Erreur SQL : " .. tostring(err))
        return nil, err
    end

    return affectedRows
end

-- Alias pour conserver l'interface Query().
function SQLite.Query(query, ...)
    return SQLite.Execute(query, ...)
end

-- Récupère les résultats d'un SELECT.
function SQLite.Select(query, ...)
    if not SQLite.Connected or not SQLite.Connection then
        return nil, "SQLite n'est pas connecté."
    end

    if type(query) ~= "string" or query == "" then
        return nil, "Requête SQL invalide."
    end

    local rows, err =
        SQLite.Connection:Select(query, ...)

    if err then
        print("[YRM] Erreur SQL : " .. tostring(err))
        return nil, err
    end

    return rows
end

-- Ferme la connexion.
function SQLite.Close()
    if not SQLite.Connection then
        SQLite.Connected = false
        return true
    end

    local connection = SQLite.Connection

    local success, err = pcall(function()
        connection:Close()
    end)

    SQLite.Connection = nil
    SQLite.Connected = false

    if not success then
        print("[YRM] Erreur à la fermeture SQLite : " .. tostring(err))
        return false, err
    end

    print("[YRM] Connexion SQLite fermée.")

    return true
end

return SQLite
