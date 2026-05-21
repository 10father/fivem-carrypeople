fx_version "cerulean"
game "gta5"

author "Codex"
description "Standalone carry player script"
version "1.0.0"

shared_scripts {
    "@ox_lib/init.lua",
    "config.lua"
}

client_scripts {
    "client.lua"
}

server_scripts {
    "server.lua"
}
