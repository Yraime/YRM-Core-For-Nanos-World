
local Persistence = {}

Persistence.Dirty = {}
Persistence.IsSaving = false

local config = YRM.Config.Persistence or {}
Persistence.Enabled = config.Enabled ~= false
Persistence.SaveInterval = config.SaveInterval or 300

-- Signale qu'une donnée doit être sauvegardée.
-- store : nom du système, ex. "players" ou "inventory"
-- key   : identifiant stable, ex. le Steam ID
-- save  : fonction qui effectue la sauvegarde et renvoie true en cas de succès
function Persistence.MarkDirty(store, key, save)
    if type(store) ~= "string" or type(key) ~= "string" then
        print("[YRM] MarkDirty : store ou clé invalide.")
        return false, "Le store et la clé doivent être des chaînes."
    end

    if type(save) ~= "function" then
        print("[YRM] MarkDirty : fonction de sauvegarde invalide.")
        return false, "La fonction de sauvegarde est invalide."
    end

    Persistence.Dirty[store] = Persistence.Dirty[store] or {}
    Persistence.Dirty[store][key] = save

    print("[YRM] Donnée marquée pour sauvegarde : "
        .. store .. "/" .. key)

    return true
end

local function SaveEntry(store, key, save)
    local success, result, err = pcall(save, key)

    if success and result == true then
        -- Ne supprime l'entrée que si elle n'a pas été
        -- remplacée par une nouvelle modification entre-temps.
        if Persistence.Dirty[store]
            and Persistence.Dirty[store][key] == save then
            Persistence.Dirty[store][key] = nil
        end

        if Persistence.Dirty[store]
            and next(Persistence.Dirty[store]) == nil then
            Persistence.Dirty[store] = nil
        end

        return true
    end

    print("[YRM] Sauvegarde échouée (" .. store .. "/" .. key .. ") : "
        .. tostring(success and (err or result) or result))

    return false
end

function Persistence.FlushDirty()
    if Persistence.IsSaving then
        return false, "Une sauvegarde est déjà en cours."
    end

    Persistence.IsSaving = true
    local failed = 0

    -- Copie les entrées pour éviter de parcourir une table
    -- que les modules peuvent modifier pendant la sauvegarde.
    local pending = {}

    for store, entries in pairs(Persistence.Dirty) do
        for key, save in pairs(entries) do
            pending[#pending + 1] = {
                Store = store,
                Key = key,
                Save = save
            }
        end
    end

    for _, entry in ipairs(pending) do
        if not SaveEntry(entry.Store, entry.Key, entry.Save) then
            failed = failed + 1
        end
    end

    Persistence.IsSaving = false

    if failed > 0 then
        return false, failed .. " sauvegarde(s) en échec."
    end

    return true
end

-- Sauvegarde toutes les données en attente pour une clé,
-- par exemple lors de la déconnexion d'un joueur.
function Persistence.FlushKey(key)
    if Persistence.IsSaving then
        return false, "Une sauvegarde est déjà en cours."
    end

    Persistence.IsSaving = true
    local pending = {}

    for store, entries in pairs(Persistence.Dirty) do
        if entries[key] then
            pending[#pending + 1] = {
                Store = store,
                Key = key,
                Save = entries[key]
            }
        end
    end

    local failed = 0

    for _, entry in ipairs(pending) do
        if not SaveEntry(entry.Store, entry.Key, entry.Save) then
            failed = failed + 1
        end
    end

    Persistence.IsSaving = false
    return failed == 0, failed > 0 and "Échec de sauvegarde." or nil
end

function Persistence.Start()
    if not Persistence.Enabled then
        print("[YRM] Sauvegardes automatiques désactivées.")
        return
    end

    if Persistence.Timer then
        return
    end

    Persistence.Timer = Timer.SetInterval(function()
        local success, err = Persistence.FlushDirty()

        if not success then
            print("[YRM] Sauvegarde périodique : " .. tostring(err))
        end
    end, Persistence.SaveInterval * 1000)

    print("[YRM] Sauvegarde automatique activée : toutes les "
        .. Persistence.SaveInterval .. " secondes.")
end

return Persistence
