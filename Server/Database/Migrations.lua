
local Migrations = {}

Migrations.Tables = {
    sqlite = {
        [[
            CREATE TABLE IF NOT EXISTS yrm_players (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                steam_id TEXT NOT NULL UNIQUE,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_seen DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                data TEXT
            )
        ]]
    },

    mysql = {
        [[
            CREATE TABLE IF NOT EXISTS yrm_players (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                steam_id VARCHAR(64) NOT NULL UNIQUE,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_seen DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                data LONGTEXT,
                PRIMARY KEY (id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]
    }
}

function Migrations.Run()
    if not YRM.Database or not YRM.Database.IsConnected() then
        print("[YRM] Erreur : base de données non connectée.")
        return false
    end

    local databaseType = YRM.Database.Type
    local tables = Migrations.Tables[databaseType]

    if not tables then
        print("[YRM] Moteur de base de données inconnu.")
        return false
    end

    for index, query in ipairs(tables) do
        local result, err = YRM.Database.Execute(query)

        if result == nil then
            print(
                "[YRM] Migration " .. index ..
                " échouée : " .. tostring(err)
            )
            return false
        end
    end

    print("[YRM] Migrations exécutées : " .. databaseType)
    return true
end

return Migrations
