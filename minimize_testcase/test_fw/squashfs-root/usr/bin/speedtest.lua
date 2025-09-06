#!/usr/bin/env lua
xml = require('xml')
json = require('json')
requests = require('requests')
socket = require('socket')


function pp_exec(command)
    local pp = io.popen(command)
    local data = pp:read("*a")
    pp:close()
    return data
end

function string:split(delimiter)
    local result = { }
    local from  = 1
    local delim_from, delim_to = string.find( self, delimiter, from  )
    while delim_from do
        table.insert( result, string.sub( self, from , delim_from-1 ) )
        from  = delim_to + 1
        delim_from, delim_to = string.find( self, delimiter, from  )
    end
    table.insert( result, string.sub( self, from  ) )
    return result
end


-- Get client config
-- Return lon, lat, cc, isp
function get_client_config()
    response = requests.get('https://www.speedtest.net/speedtest-config.php')
    local config = xml.load(response.text)
    local client_elem = xml.find(config, 'client')
    print("lon=" .. client_elem['lon'] .. ", lat=" .. client_elem['lat'])
    print("country=" .. client_elem['country'] .. ", isp=" .. client_elem['isp'])

    return client_elem['lon'], client_elem['lat'], client_elem['country'], client_elem['isp']
end

-- Save client config to /var/gdata/speedtest/client.conf
--file = io.open("/var/gdata/speedtest/client.conf", "w")
--io.output(file)
--io.write(json.encode(client_elem))
--io.close(file)

-- Get the distance in km
function get_distance(from_lon, from_lat, to_lon, to_lat)
    local cos = math.cos
    local sin = math.sin
    local pi = math.pi
    local sqrt = math.sqrt
    local min = math.min
    local asin = math.asin
    local abs = math.abs
    local distance = 0
    local radius = 6367000
    local radian = pi / 180
    local deltaLatitude = sin(radian * (from_lat - to_lat) /2)
    local deltaLongitude = sin(radian * (from_lon - to_lon) / 2)
    local circleDistance = 2 * asin(min(1, sqrt(deltaLatitude * deltaLatitude + cos(radian * from_lat) * cos(radian * to_lat) * deltaLongitude * deltaLongitude)))
    distance = abs(radius * circleDistance)
    return distance / 1000
end

-- Get the best server
function get_best_server(cc, isp, lon, lat)
    --response = requests.get('https://c.speedtest.net/speedtest-servers-static.php')
    --local settings = xml.load(response.text)
    local settings = xml.loadpath('/etc/speedtest-servers-static.xml')
    local servers = xml.find(settings, 'servers')
    local cc_servers = {}
    local top5_servers = {}
    local i = 0

    -- Get server list with the same country code
    for _, server in pairs(servers) do
        if server['cc'] == cc then
            table.insert(cc_servers, server)
        end
    end

    -- Get the closest top 5 servers
    for _, server in pairs(cc_servers) do
        server['dist'] = get_distance(lon, lat, server['lon'], server['lat'])
    end

    table.sort(cc_servers, function(a,b)
        return a['dist'] < b['dist']
    end)

    for _, server in pairs(cc_servers) do
        table.insert(top5_servers, server)
        i = i+1
        if (i>=5) then
            break
        end
    end

    -- Get the best server with the lowest latency
    for _, server in pairs(top5_servers) do
        print("Detect latency for " .. server['host'])
        start_time = socket.gettime()*1000
        local r, response = pcall(requests.get, {"http://"..server['host'], timeout = 1})
        --response = requests.get{"http://"..server['host'], timeout = 1}
        end_time = socket.gettime()*1000
        elapsed_time = os.difftime(end_time-start_time)
        server['latency'] = elapsed_time
    end

    table.sort(top5_servers, function(a,b)
        return a['latency'] < b['latency']
    end)

    best = table.remove(top5_servers, 1)
    return best['url'], best['dist'], best['latency']
end


--
-- MAIN
--
lon, lat, cc, isp = get_client_config()
url, dist, latency = get_best_server(cc, isp, lon, lat)
print("The Best Server : " .. url)
print("Distance (km)   : " .. dist)
print("Latency (ms)    : " .. latency)
result = pp_exec("speedtest -s " .. url):gsub("\n", "")
data = {}
for d in result:gmatch("%w+") do table.insert(data, d) end
print("Download (kbps) : " .. data[1])
print("Upload (kbps)   : " .. data[2])
