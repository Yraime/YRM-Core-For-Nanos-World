YRM = YRM or {}
YRM.Config = YRM.Config or {}

YRM.Database = Package.Require("Database/Index.lua")

local connected, connectError = YRM.Database.Connect()
if not connected then
    error("[YRM] Échec de connexion à la base : " .. tostring(connectError))
end

YRM.Migrations = Package.Require("Database/Migrations.lua")
if not YRM.Migrations.Run() then
    error("[YRM] Échec des migrations.")
end

YRM.Players = Package.Require("Database/Players.lua")

YRM.Persistence = Package.Require("Server/Persistence/Index.lua")
YRM.Persistence.Start()

YRM.Session = Package.Require("Modules/Session.lua")
YRM.UniqueID = Package.Require("Modules/UniqueID.lua")

Package.Require("Commands.lua")
Package.Require("Commands/Admin.lua")

Player.Subscribe("Spawn", function(player)
    local success, err = YRM.Players.Save(player)
    if not success then
        print("[YRM] Erreur de sauvegarde du profil : " .. tostring(err))
    end
end)

Server.Subscribe("PlayerDisconnect", function(ip, accountID, playerName, steamID, reason)
    if not steamID or steamID == "" then
        return
    end

    local success, err = YRM.Persistence.FlushKey(tostring(steamID))
    if not success then
        print("[YRM] Erreur de sauvegarde à la déconnexion : " .. tostring(err))
    end
end)

Server.Subscribe("Stop", function()
    local success, err = YRM.Persistence.FlushDirty()
    if not success then
        print("[YRM] Attention : " .. tostring(err))
    end

    if YRM.Database.Close then
        local closed, closeError = YRM.Database.Close()
        if closed == false then
            print("[YRM] Erreur de fermeture de la base : " .. tostring(closeError))
        end
    end
end)

Package.Export("YRM", YRM)

print("[YRM] Core initialisé avec succès.")