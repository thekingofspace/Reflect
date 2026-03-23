local module = {}
local net = require("@lune/net")
local serde = require("@lune/serde")
local task = require("@lune/task")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local path_info = require("./get_info")

module.Paths = {}
module.Staged_Actions = {}
module.Last_Heatbeat = os.time()
module.Init_pack = false
print("")

local function log_info(msg: string)
    if path_info.log_actions.connection == true then
        stdio.write(stdio.color("blue"))
        stdio.write(stdio.style("bold"))
        stdio.write("[INFO] ")
        stdio.write(stdio.style("reset"))
        stdio.write(stdio.color("reset"))
        print(msg)
    end
end

local function log_success(msg: string)
    if path_info.log_actions.connection == true then
        stdio.write(stdio.color("green"))
        stdio.write(stdio.style("bold"))
        stdio.write("[OK]   ")
        stdio.write(stdio.style("reset"))
        stdio.write(stdio.color("reset"))
        print(msg)
    end
end

local function log_warn(msg: string)
    if path_info.log_actions.warn == true then
        stdio.write(stdio.color("yellow"))
        stdio.write(stdio.style("bold"))
        stdio.write("[WARN] ")
        stdio.write(stdio.style("reset"))
        stdio.write(stdio.color("reset"))
        print(msg)
    end
end

local function log_error(msg: string)
    if path_info.log_actions.error == true then
        stdio.write(stdio.color("red"))
        stdio.write(stdio.style("bold"))
        stdio.write("[ERR]  ")
        stdio.write(stdio.style("reset"))
        stdio.write(stdio.color("reset"))
        print(msg)
    end
end

------------------------------------- Core functions

function module.RegisterPath(method: net.HttpMethod, callback: (packet: net.ServeRequest) -> net.ServeResponse)
    module.Paths[method] = callback
    return module
end

function module.Begin_net()
    if not path_info.project_name then
        log_error("Cannot start server: project_name is missing from path_info")
        return
    end

    local port = path_info.default_port or 8088
    log_info("Starting server for project: " .. tostring(path_info.project_name))
    log_info("Listening on port: " .. tostring(port))
    if path_info.two_way_scripting == true then
        log_warn("two_way_scripting is enabled this can cause unintended behaviour.")
    end

    net.serve(port, function(packet: net.ServeRequest)
        if module.Paths[packet.method] then
            local response = module.Paths[packet.method](packet)
            return response
        else
            log_warn("No handler for method: " .. packet.method .. " — responding 405")
            return { status = 405 }
        end
    end)
end

------------------------------------- Setup callbacks

module
    .RegisterPath("PATCH", function(packet)
        module.Last_Heatbeat = os.time()

        if module.Init_pack then
            local res_pack = {}

            if #module.Staged_Actions > 0 then
                local batch_size = math.min(25, #module.Staged_Actions)
                for _ = 1, batch_size do
                    table.insert(res_pack, table.remove(module.Staged_Actions, 1))
                    if #module.Staged_Actions == 0 then break end
                end
                log_info("Flushed " .. tostring(#res_pack) .. " staged action(s) — " .. tostring(#module.Staged_Actions) .. " remaining")
            else
                log_info("Heartbeat received — no staged actions to flush")
            end

            return {
                status = 202,
                body = serde.encode("json", res_pack)
            }
        else
            log_success("Initial handshake received — sending path_info to client")

            task.spawn(function()
                log_info("Heartbeat watchdog started (interval: " .. tostring(path_info.heartbeat_interval) .. "s)")
                while true do
                    task.wait(1)
                    local elapsed = os.time() - module.Last_Heatbeat
                    if elapsed > path_info.heartbeat_interval + 1 then
                        log_error("Heartbeat timeout — no ping for " .. tostring(elapsed) .. "s. Shutting down.")
                        process.exit()
                    end
                end
            end)

            module.Init_pack = true
            return {
                status = 200,
                body = serde.encode("json", path_info)
            }
        end
    end)

------------------------------------- Return out
return module