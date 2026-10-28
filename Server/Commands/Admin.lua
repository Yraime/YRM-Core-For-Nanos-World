local function Notify(player, description, notifType, title, duration)
    if not player then
        return
    end

    Events.CallRemote(
        "YRM:Notify",
        player,
        Reliability.Reliable,
        {
            title = title or "YRM Core",
            description = description,
            position = "top-left",
            type = notifType or "info",
            duration = duration or 5000
        }
    )
end

YRM.RegisterCommand("heal", {
    Description = "Soigner un joueur par son ID",

    OnExecute = function(player, args)
        if not player then
            return
        end

        local targetPlayer = player

        if args[1] then
            local found, err = YRM.FindPlayerByID(args[1])

            if not found then
                Notify(player, err or "Joueur introuvable.", "error")
                return
            end

            targetPlayer = found
        end

        local character = targetPlayer:GetControlledCharacter()

        if not character then
            Notify(player, "Ce joueur n'a aucun personnage disponible.", "error")
            return
        end

        character:SetHealth(character:GetMaxHealth())

        Notify(
            player,
            "Joueur soigné (ID "
                .. tostring(YRM.GetCommandID(targetPlayer)) .. ").",
            "success"
        )

        if targetPlayer ~= player then
            Notify(targetPlayer, "Vous avez été soigné.", "success")
        end
    end
})

YRM.RegisterCommand("id", {
    Description = "Afficher ses identifiants",

    OnExecute = function(player, args)
        if not player then
            return
        end

        local description =
            "Steam ID : " .. tostring(player:GetSteamID())
            .. "\nNanos ID : " .. tostring(player:GetID())

        if YRM.Config.UniqueID and YRM.Config.UniqueID.Enabled then
            local uniqueID, err = YRM.GetUniqueID(player)

            description = description
                .. "\nUnique ID : "
                .. (uniqueID ~= nil
                    and tostring(uniqueID)
                    or ("Erreur : " .. tostring(err)))
        end

        Notify(
            player,
            description,
            "access",
            "YRM Core - Mes identifiants",
            10000
        )
    end
})