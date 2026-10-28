
    local MySQL = {}

    MySQL.Connection = nil
    MySQL.Connected = false

    local function BuildConnectionString(config)
        local host = tostring(config.Host or "127.0.0.1")
        local port = tonumber(config.Port) or 3306
        local username = tostring(config.Username or "")
        local password = tostring(config.Password or "")
        local database = tostring(config.Database or "")

        if username == "" or database == "" then
            return nil, "Identifiants MySQL ou nom de base manquants."
        end

        if host:find("[%s\r\n]")
            or username:find("[%s\r\n]")
            or password:find("[%s\r\n]")
            or database:find("[%s\r\n]") then
            return nil, "Les paramètres de connexion ne doivent pas contenir d'espaces."
        end

        if port < 1 or port > 65535 or port % 1 ~= 0 then
            return nil, "Port MySQL invalide."
        end

        return string.format(
            "host=%s port=%d user=%s password=%s db=%s charset=utf8mb4 connect_timeout=5",
            host,
            port,
            username,
            password,
            database
        )
    end

    function MySQL.Connect(config)
        if MySQL.Connected then
            return true
        end

        if type(config) ~= "table" then
            return false, "Configuration MySQL invalide."
        end

        local connectionString, configError =
            BuildConnectionString(config)

        if not connectionString then
            return false, configError
        end

        local ok, connection = pcall(function()
            return Database(
                DatabaseEngine.MySQL,
                connectionString
            )
        end)

        if not ok then
            return false, tostring(connection)
        end

        if not connection then
            return false, "Impossible de se connecter à MySQL."
        end

        MySQL.Connection = connection
        MySQL.Connected = true

        print("[YRM] Connexion MySQL établie.")

        return true
    end

    function MySQL.Execute(query, ...)
        if not MySQL.Connected or not MySQL.Connection then
            return nil, "MySQL n'est pas connecté."
        end

        local parameters = {...}

        local ok, affectedRows, err = pcall(function()
            return MySQL.Connection:Execute(
                query,
                table.unpack(parameters)
            )
        end)

        if not ok then
            return nil, tostring(affectedRows)
        end

        if affectedRows == nil then
            return nil, err or "Échec de la requête MySQL."
        end

        if err then
            return nil, err
        end

        return affectedRows
    end

    function MySQL.Select(query, ...)
        if not MySQL.Connected or not MySQL.Connection then
            return nil, "MySQL n'est pas connecté."
        end

        local parameters = {...}

        local ok, rows, err = pcall(function()
            return MySQL.Connection:Select(
                query,
                table.unpack(parameters)
            )
        end)

        if not ok then
            return nil, tostring(rows)
        end

        if rows == nil then
            return nil, err or "Échec de la lecture MySQL."
        end

        if err then
            return nil, err
        end

        return rows
    end

    function MySQL.Close()
        if not MySQL.Connection then
            MySQL.Connected = false
            return true
        end

        local connection = MySQL.Connection

        local ok, err = pcall(function()
            connection:Close()
        end)

        MySQL.Connection = nil
        MySQL.Connected = false

        if not ok then
            return false, tostring(err)
        end

        print("[YRM] Connexion MySQL fermée.")

        return true
    end

    return MySQL
