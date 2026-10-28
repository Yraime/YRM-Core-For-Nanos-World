YRM = YRM or {}
YRM.Config = YRM.Config or {}

YRM.Config.Database = {
    Type = "sqlite",
    UTCOffset = 2,
    SQLite = { Path = "yrm_core.db" },
    MySQL = {
        Host = "127.0.0.1",
        Port = 3306,
        Username = "yrm_user",
        Password = "",
        Database = "yrm_core"
    }
}

YRM.Config.Persistence = {
    Enabled = true,
    SaveInterval = 300
}


-- YRM.Config.UniqueID = { Enabled = true } soon...


YRM.Config.CommandPrefix = "/"