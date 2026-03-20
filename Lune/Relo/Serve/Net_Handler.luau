local module = {}
local net = require("@lune/net")
local serde = require("@lune/serde")
local project_info = require("./get_info")

local c = {
    reset   = "\27[0m",
    bold    = "\27[1m",
    white   = "\27[37m",
    yellow  = "\27[33m",
    cyan    = "\27[96m",
    magenta = "\27[95m",
    red     = "\27[91m",
    green   = "\27[92m",
}

local function paint(color: string, text: string): string
    return color .. text .. c.reset
end

local function bold(color: string, text: string): string
    return paint(c.bold .. color, text)
end

local function log_request(method: string, path: string, status: number)
    local status_color = status >= 500 and c.red
        or status >= 400 and c.yellow
        or c.green

    print(
        bold(c.white, "[") .. paint(c.cyan, method) .. bold(c.white, "]") ..
        " " .. paint(c.white, path) ..
        " " .. bold(c.white, "→") ..
        " " .. paint(status_color, tostring(status))
    )
end

local actions = {
    ["GET"] = function(packet: net.ServeRequest)
        local true_path = packet.path:split("/")
        table.remove(true_path, 1)

        local endpack: any = nil
        if true_path[1] == "info" then
            endpack = {
                status = 200,
                body = serde.encode("json", project_info)
            } :: net.ServeResponse
        end

        local status = endpack and endpack.status or 404
        if project_info.log_actions.connection == true then
            log_request("GET", packet.path, status)
        end
        return endpack
    end
}

function module.Begin_net()
    local port = project_info.default_port
    local url = `http://localhost:{port}`

    print(" " .. bold(c.white, "Server starting"))
    print("  " .. paint(c.white, "Local:") .. "   " .. paint(c.cyan, url))
    print("  " .. paint(c.white, "Port:") .. "    " .. paint(c.yellow, tostring(port)))
    print(paint(c.magenta, ("─"):rep(36)))

    net.serve(port, function(packet: net.ServeRequest)
        local handler = actions[packet.method]
        if handler then
            return handler(packet)
        else
            log_request(packet.method, packet.path, 405)
            return { status = 405 }
        end
    end)
end

return module