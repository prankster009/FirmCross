-- runtime.lua
local json = require('json')
local runtime = {}

functions = {
	dhcpClientT = function(arg) 
			local r, retjson = pcall(runtime.dhcpClientT, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,     
 	wlanClientT = function(arg) 
			local r, retjson = pcall(runtime.wlanClientT, arg)
            
        		if r then
				return retjson
			else
				return '{"wlanClientT":"NOK"}'
            		end
		end,
	RouterInfo = function(arg) 
			local rt=runtime.RouterInfo(arg)
			return rt
		end,
	InternetConnection = function(arg)
			local rt = runtime.InternetConnection(arg)
			return rt
		end,
	LocalNetwork = function(arg)
			local rt = runtime.LocalNetwork(arg)
			return rt
		end,
	Wifi5G = function(arg)
			local rt = runtime.Wifi5G(arg)
			return rt
		end,
	Wifi2G = function(arg)
			local rt = runtime.Wifi2G(arg)
			return rt
		end,
	portStatus = function(arg)
			local r, retjson = pcall(runtime.portStatus, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,
        pingTest = function(arg)
			local r, retjson = pcall(runtime.pingTest, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
                end,
        traceRoute = function(arg)
			local r, retjson = pcall(runtime.traceRoute, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
                end,
	deviceReset =  function(arg)
			local r, retjson = pcall(runtime.deviceReset, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,
	showRouteT =  function(arg)
			local r, retjson = pcall(runtime.showRouteT, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,
	checkFW = function(arg)
			local r, retjson = pcall(runtime.checkFW, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,

	wpsProcess =  function(arg)    
	        	local rt = runtime.wpsProcess(arg)
	       		return rt
        	end,  
	wscMonitor = function(arg)
    
    			local rt = runtime.wscMonitor(arg)
			return rt
		end,
	dhcpAction = function(arg)
			local rt = runtime.dhcpAction(arg)
			return rt
		end,
	macClone = function(arg)
			local rt = runtime.macClone(arg)
			return rt
		end,
	vpnAction = function(arg)
			local rt = runtime.vpnAction(arg)
			return rt
		end,
	v6rdAction = function(arg)
			local rt = runtime.v6rdAction(arg)
			return rt
		end,
	systemLog = function(arg)
			local rt = runtime.systemLog(arg)
			return rt
		end,
	dhcp6cDuid = function(arg)
			local rt = runtime.dhcp6cDuid()
			return rt
		end,
	hosts = function(arg)
			local rt = runtime.hosts()
			return rt
		end,
	ddnsStatus = function(arg)
			local rt = runtime.ddnsStatus(arg)
			return rt
		end,
	autowan = function(arg)
			local rt = runtime.autowan(arg)
			return rt
		end,
        getPolicy = function(arg)
			local rt = runtime.getPolicy(arg)
			return rt
		end,
	connStatus = function(arg)
			local rt = runtime.connStatus(arg)
			return rt
		end,
	emailReg = function(arg)
			local rt = runtime.emailReg(arg)
			return rt
		end,
        
    wlanbridgeTest = function(arg)
            local rt = runtime.wlanbridgeTest(arg)
            return rt
        end,        

	easyMesh = function(arg)
			local r, retjson = pcall(runtime.easyMesh, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,

	easyMeshWps = function(arg)
			local r, retjson = pcall(runtime.easyMeshWps, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,

	easyMeshMsg = function(arg)
			local r, retjson = pcall(runtime.easyMeshMsg, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,

	easyMeshSetName = function(arg)
			local r, retjson = pcall(runtime.easyMeshSetName, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,

	easyMeshNewAgent = function(arg)
			local r, retjson = pcall(runtime.easyMeshNewAgent, arg)
			if r then
				return retjson
			else
				return '"NOK"'
			end
		end,
}

function runtime.infolist(str)
        local rt = {}
        if str ~= nil and string.len(str) ~= 0  then
                local cstr = string.gsub(str, "&_=.*", '')
		print("Get "..cstr)
                string.gsub(cstr, '[^%p*]+', function(w) table.insert(rt, w) end )
                if #rt ~= 0 then
                        if rt[1] == 'list' then
                                table.remove(rt, 1)
                        else
                                print("[Error] input obj list not correct!!!")
                                rt = {}
                        end
                end
        end

        return rt
end

function runtime.merge_infolistjson(str)
        local tab = {}
        tab = runtime.infolist(str)

        local mstr = ''
        if type(tab) == "table" then
                for i,t in ipairs(tab) do
                        print('merge info '.. t)
			-- Do not need parameter for get function
			if functions[t] then
				mstr = runtime.merge_json(mstr, functions[t]())
			end
                end
                --mstr = string.gsub(mstr, '%s', '')
        end

        return mstr
end

function runtime.merge_json(orijson, addjson)
        local retjson = orijson
	if addjson == nil then
		addjson = {}
	end
        if string.len(retjson) == 0 then
                retjson = addjson
        else
                local tmpori = string.gsub (string.reverse(orijson), '}', ',', 1)
                local tmpadd = string.reverse(string.gsub (addjson, '{', '', 1))
                retjson = string.reverse(tmpadd..tmpori)
        end

        return retjson
end


--[[function runtime.checkIfWIFI(mac)

    local ret 
    local cmd = "cat /tmp/wlan.info | grep " ..mac
    print(cmd)
	local f = assert(io.popen(cmd, 'r'))
	s = f:read()
    
	if s == nil then
        
		ret = 0	
    else
        ret = 1
    end
    f:close()
    
	return ret
end]]--

function runtime.getMACif(mac)
        local ret="-"
        local p=assert(io.popen("cat /sys/class/net/br-lan/brif/ra0/port_no | cut -d 'x' -f2"))
        local ra0key=string.gsub(assert(p:read('*a')), "\n", "")
        p:close()

        p=assert(io.popen("cat /sys/class/net/br-lan/brif/rai0/port_no | cut -d 'x' -f2"))
        local rai0key=string.gsub(assert(p:read('*a')), "\n", "")
        p:close()

        --print("ra0 ["..ra0key.."], rai0 ["..rai0key.."]")
        local s = ''
        local f = assert(io.popen("cat /sys/class/net/br-lan/brforward > /tmp/brforward; hexdump -v -e \'5/1 \"%02x:\" /1 \"%02x\" /1 \" %x\" /1 \" %x\" 1/4 \" %i\" 1/4 \"\n\"\' /tmp/brforward", 'r'))
        while true do
                s = f:read()
                if s == nil then
                        break
                end
                if string.find(s, mac) then
                        local rt = {}
                        string.gsub(s, '[^%s*]+', function(w) table.insert(rt, w) end )
                        --PrintTable(rt)
                        if rt[2] == ra0key or rt[2] == rai0key then
                                ret="wifi"
			else
				ret="lan"
                        end
                end
        end
        f:close()

        return ret
end

function runtime.expireTime(leasetime)
	local nowtime = os.time()
	local exptime = leasetime - nowtime
	if exptime < 0 then
		exptime = 0
	end
	return exptime
end

function runtime.splitdhcpinfo(linestr, sep)
	local t={}
	local keyt={"alivetime","mac","assignedIp","hostname"}
	
	sep = sep or '%s'
	local i = 1
	for field,s in string.gmatch(linestr, "([^"..sep.."]*)("..sep.."?)") do
		--table.insert(t,field)
		if i < 5 then
			t[keyt[i]] = field
			i = i+1
		end
	end

	--Check dhcp client interface by mac
	t["interface"] = runtime.getMACif(t["mac"])

	if t["interface"] == "-" then
		t["alivetime"]="0"
	else
		--Reset lease time to expire time
		t["alivetime"] = runtime.expireTime(t["alivetime"])
	end

	--[[if runtime.checkIfWIFI(t["mac"]) == 1 then
		t["interface"] = "wifi"
	else
		t["interface"] = "lan"
	end]]--

	return t
end

function runtime.dhcpClientT(pt)
	local rt = {}
	local crt = {}
	local jrt = {}
        local cmd = "/usr/bin/wlanlist"
    
	--print("Do ["..cmd.."]")
	os.execute(cmd)

	local updateleasefile=0
	local newfile
        if pt ~= nil then
		updateleasefile=1
		newfile = io.open ("/tmp/dhcp.leases.new", "w")
        end

	local p=assert(io.popen("ifconfig br-lan | grep \'inet addr\' | cut -d: -f2 | cut -d. -f1-3"))
	local brsubip=string.gsub(assert(p:read('*a')), "\n", "")
	p:close()

	for line in io.lines('/tmp/dhcp.leases') do
		if updateleasefile == 1 then
			if string.find(line, pt["mac"]) then
				print('Delete mac '..pt["mac"])
			else
				newfile:write(line..'\n')
			end
		else
			print('Parse '..line)
			if string.find(line, brsubip..'.') then
				rt = runtime.splitdhcpinfo(line, ' ')
				table.insert(crt, rt)
			end
		end
	end

	if updateleasefile == 1 then
		io.close(newfile)
		os.execute('/etc/init.d/dnsmasq stop && mv /tmp/dhcp.leases.new /tmp/dhcp.leases')
		os.execute('/etc/init.d/dnsmasq start')
		return '"OK"'
	else
		--Set to final json
		jrt["dhcpClientT"] = crt
		return json.encode(jrt)
	end
end

function runtime.splitwlaninfo(linestr, sep)
	local t={}
	local keyt={"hostname","interface","mac","assignedIp", "status"}
	

	sep = sep or '%s'
	local i = 1
	for field,s in string.gmatch(linestr, "([^"..sep.."]*)("..sep.."?)") do
        
		if i < 6 then
			t[keyt[i]] = field
			i = i+1
		end
	end
    
	return t
end


function runtime.wlanClientT(str)
	local rt = {}
	local crt = {}
	local jrt = {}
    
        local cmd = "/usr/bin/wlanlist"
	print("Do ["..cmd.."]")
	os.execute(cmd)
    
    
	for line in io.lines('/tmp/wlan.info') do
		print('Parse '..line)
		rt = runtime.splitwlaninfo(line, ' ')
        
		table.insert(crt, rt)
	end

	--Set to final json
	jrt["wlanClientT"] = crt
	--PrintTable(jrt)
	return json.encode(jrt)
   
end

function runtime.savefileline(filepath, act, count)
	local ret = 0
	file = io.open(filepath..".count", act)
	if file then
		if act == "r" then
			ret = file:read()
		else
			ret = file:write(count)
		end
		file:close()
	end

	return ret
end

function runtime.showfilefromline(jname, filepath, shownumber)
	local rt = {}
	local jrt = {}
	local startline = tonumber(runtime.savefileline(filepath, "r"))
	local readline = 1
	local endflag = 1
	print("From line "..startline)
	for line in io.lines(filepath) do
		if readline == startline+tonumber(shownumber) then
			--Not end of file
			endflag = 0
			break
		elseif readline >= startline then
			if string.len(line) < 2 or string.len(line) > 12 then
				table.insert(rt, line)
			else
				break
			end
		end
		readline = readline+1
	end
	runtime.savefileline(filepath, "w", readline)

	if endflag ~= 0 then
		table.insert(rt, "-1")
	else
		print("[Message Continuie!!!]")
	end

	jrt[jname] = rt
	return json.encode(jrt)
end


function runtime.pingTest(pt)
	local ret = '"NOK"'
	local logpath = "/tmp/ping.log"
	if pt ~= nil then
		print("Stop pingTest")
		os.execute("killall -2 ping")
		ret = '"OK"'
		if pt["count"] ~= nil and pt["pkgsize"] ~= nil and pt["ipurl"] ~=nil then
			--For x86 -c option is not work
			local copt=' '
			if pt["count"] ~= '0' then
				copt = " -c "..pt["count"]..copt
			end
			local cmd = "/bin/ping -W1"..copt.."-s "..pt["pkgsize"].." "..pt["ipurl"].." > "..logpath.." 2>&1 &"
			print("Do ["..cmd.."]")
			os.execute(cmd)
			runtime.savefileline(logpath, "w", "1")
			ret = '"OK"'
		end
		return ret
	else
		print("Only get ping result")
		ret = runtime.showfilefromline("pingTest", logpath, 1)
	end

	return ret
end

function runtime.traceRoute(pt)
	local ret = '"NOK"'
	local logpath = "/tmp/traceroute.log"
	if pt ~= nil then
		print("Stop traceRoute")
		os.execute("killall -9 traceroute")
		ret = '"OK"'
		if pt["ipurl"] ~= nil then
			local cmd = "/usr/bin/traceroute -I "..pt["ipurl"].." > "..logpath.." 2>&1 &"
			print("Do ["..cmd.."]")
			os.execute(cmd)
			runtime.savefileline(logpath, "w", "1")
			ret = '"OK"'
		end
	else
		print("Only get traceroute result")
		ret = runtime.showfilefromline("traceRoute", logpath, 1)
	end

	return ret
end

function runtime.exeparam(str)
	local r, gettab = pcall(json.decode, str)
	local mstr = ''
	if r then
		for k,v in pairs(gettab) do
			if functions[k] then
				--Do first key function only
				mstr = '{"'..k..'":'..functions[k](v)..'}'
				break
			else
				mstr = '{"'..k..'":"NOK"}'
			end
		end
	else
		print("Error json format!!!")
	end
	return mstr
end

function runtime.portStatus()
	local wstr = ''
	local lstr = ''
	local s = ''
	local f = assert(io.popen("/usr/sbin/ethstt", 'r'))
	while true do
		s = f:read()
		if s == nil then
			break
		end
		local rt = {}
		local pst ='0'
		string.gsub(s, '[^%s*]+', function(w) table.insert(rt, w) end )
		if rt[2] == '4' then
			--print(" do wan")
			if rt[3] == 'up' then
				pst = '1'	
			end
			wstr='"WanPort0":"'..pst..'"'
		else
			--print("do lan")
			if lstr ~= '' then
				lstr = lstr..','
			end
			if rt[3] == 'up' then
				pst = '1'
			end
			local portn = tonumber(rt[2])
			if portn ~= nil then
				lstr=lstr..'"LanPort'..portn..'":"'..pst..'"'
			end
		end
	end
	f:close()
	--print("wstr="..wstr)
	--print("lstr="..lstr)

	local finstr = '{"portStatus":{"WAN":{'..wstr..'},"LAN":{'..lstr..'}}}'

	return finstr
end

function runtime.deviceReset(pt)
	local ret = '"NOK"'
	if pt ~= nil and pt["action"] ~= nil then
		if pt["action"] == "reboot" then
			os.execute("rcConf start sysreboot")
			os.execute("rcConf run")
			return '"OK"'
		elseif pt["action"] == "reset" then
			os.execute("rcConf start sysreset")
			os.execute("rcConf run")
			return '"OK"'
		else
			print("Unknown action!!!")
		end
	end
	return ret
end

function runtime.getWan(objName, objkey)
	local ret = {}
	local rt = {}
	local cmd = 'objReq '..objName..' json'
	local r = assert(io.popen(cmd, 'r'))
	local str = assert(r:read('*a'))

	local rt = json.decode(str)
	if objkey == 'domainName' then
		ret = rt.WanP.domainName
	elseif objkey == 'hostname' then
		ret = rt.WanP.hostname
	elseif objkey == 'name' then
		cmd = 'objReq lan json'
		local p = assert(io.popen(cmd, 'r'))
		str = assert(p:read('*a'))
		local k = json.decode(str)
		ret = k.LanP.routername
		p:close()
	elseif objkey == 'mac' then
		local p = assert(io.popen('uci get network.wan.macaddr', 'r'))
		local strp = assert(p:read('*a'))
		ret = string.gsub(strp, "\n", "")
		p:close()
	end
	r:close()

	return ret
end

function runtime.RouterInfo(arg)
	local rt = {}
	local jrt = {}

	rt["MAC"] = runtime.getWan('wan','mac')
	rt["RouterName"] = runtime.getWan('wan','name')
	rt["HostName"] = runtime.getWan('wan','hostname')
	rt["DomainName"] = runtime.getWan('wan','domainName')
	rt["CurrentTime"] = os.date('%Y')..'/'..os.date('%m')..'/'..os.date('%d')..' '..os.date('%X')
	for line in io.lines('/etc/version') do
		rt["FWVersion"] = line
	end

	--Set to final json
	jrt["RouterInfo"] = rt

	return json.encode(jrt)
end

function runtime.getWanProtoStatus(objName, ver)
	local cmd =''
	local r = ''
	local str = ''
	local t = {}
	local yt = ''
	local stryt= ''
	local rt = ''
	local i = 0

	if ver == 'v4' then
		yt = assert(io.popen('ifconfig eth1 | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
		stryt = assert(yt:read('*a'))
		t["IP"] = string.gsub(stryt, "\n", "")
		yt:close()
		if string.len(t["IP"]) == 0 then
			t["IP"] = "0.0.0.0"
		end

		yt = assert(io.popen('ifconfig eth1 | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
		stryt = assert(yt:read('*a'))
		t["Netmask"] = string.gsub(stryt, "\n", "")
		yt:close()
		if string.len(t["Netmask"]) == 0 then
			t["Netmask"] = "0.0.0.0"
		end

		yt = assert(io.popen('route -n |grep \'0.0.0.0\' | grep \'UG[ \\t]\' | awk \'{print $2}\'', 'r'))
		stryt = assert(yt:read('*a'))
		t["Gateway"] = string.gsub(stryt, "\n", "")
		yt:close()
		if string.len(t["Gateway"]) == 0 then
			t["Gateway"] = "0.0.0.0"
		end

		yt = assert(io.popen('ifconfig eth1 | grep MTU | cut -d: -f2 | awk \'{print $1}\'', 'r'))
		stryt = assert(yt:read('*a'))
		t["MTU"] = string.gsub(stryt, "\n", "")
		yt:close()
	else
		-- v6, dhcp only
		yt = assert(io.popen('ifstatus wan6 | jsonfilter -e \'@[\"ipv6-address\"][0].address\'', 'r'))
		stryt = assert(yt:read('*a'))
		t["IP"] = string.lower(string.gsub(stryt, "\n", ""))
		yt:close()

		if string.len(t["IP"]) == 0 then
			t["IP"] = '0:0:0:0:0:0:0:0'
		end

		--t["Netmask"] = ""
		yt = assert(io.popen('route -A inet6 -n |grep \'::/0\' | grep \'UG[ \\t ]\' | tail -n 1| awk \'{print $2}\'', 'r'))
		stryt = assert(yt:read('*a'))
		t["Gateway"] = string.lower(string.gsub(stryt, "\n", ""))
		yt:close()
		if string.len(t["Gateway"]) == 0 then
			t["Gateway"] = '0:0:0:0:0:0:0:0'
		end

		--t["MTU"] = "1280"
		--t["ConnectionType"] = "dhcpv6"
		--t["DHCPLeaseTime"] = "100"

		yt = assert(io.popen('cat /etc/resolv.conf | wc -l'))
		stryt = assert(yt:read('*a'))
		yt:close()

		local j = 1
		t["DNS1"] = ""
		t["DNS2"] = ""
		t["DNS3"] = ""
		for i = 1,stryt do
			cmd = 'awk \'NR=='..i..'\' /etc/resolv.conf | awk \'{print $2}\''
			cmd = 'cat /tmp/resolv.conf.auto | grep \":\"| awk \'NR==\''..i..' |awk \'{print $2}\' | cut -d\'%\' -f 1'
			yt = assert(io.popen(cmd))
			stryt = assert(yt:read('*a'))
			yt:close()
			if string.find(stryt,":") then
				t["DNS"..j] = string.gsub(stryt, "\n", "")
				j = j + 1
				if j == 4 then break end
			end
		end
	end

	if objName == 'dhcp' then
		if ver == 'v4' then
			t["ConnectionType"] = "dhcp"
                        cmd = 'objReq dhcps json'
                        r = assert(io.popen(cmd, 'r'))
                        str = assert(r:read('*a'))
                        rt = json.decode(str)
			t["DNS1"] = rt.DhcpsP.dns1
			t["DNS2"] = rt.DhcpsP.dns2
			t["DNS3"] = rt.DhcpsP.dns3
			r:close()

			i = 1
			for line in io.lines('/tmp/resolv.conf.auto') do
				for m,s in string.gmatch(line, "(%w+) (%d+%.%d+%.%d+%.%d+)") do
					if string.len(t["DNS"..i]) == 0 then
						t["DNS"..i] = s
					end
					i = i + 1
				end
				if i == 4 then break end
			end

			cmd = 'ifstatus wan | jsonfilter -e @.data.leasetime'
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
			t["DHCPLeaseTime"] = string.gsub(str, "\n", "")
			r:close()
		else
			yt = assert(io.popen('uci -q get network.wan6.proto', 'r'))
			stryt = assert(yt:read('*a'))
			if string.gsub(stryt, "\n", "") == 'dhcpv6' then
				t["ConnectionType"] = "dhcpv6"
			else
				t["ConnectionType"] = string.gsub(stryt, "\n", "")
			end
			yt:close()

			cmd = 'ifstatus wan6 | jsonfilter -e \'@[\"ipv6-address\"][0].valid\''
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
			t["DHCPLeaseTime"] = string.gsub(str, "\n", "")
			r:close()
		end
	elseif objName == 'static' then
		if ver == 'v4' then
			t["ConnectionType"] = "static"
			cmd = 'objReq staticip json'
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
        		rt = json.decode(str)
			t["DNS1"] = rt.StaticipP.dns1
			t["DNS2"] = rt.StaticipP.dns2
			t["DNS3"] = rt.StaticipP.dns3
			r:close()
		else
			t["ConnectionType"] = "dhcpv6"
		end
	elseif objName == 'pppoe' then
		if ver == 'v4' then
			t["ConnectionType"] = "pppoe"
			t["DNS1"] = ""
			t["DNS2"] = ""
			t["DNS3"] = ""

			i = 1
                        local tmpdns = '/tmp/dnsfp'
                        yt = assert(io.popen('cat /tmp/resolv.conf.auto | sort | uniq > '..tmpdns))
                        stryt = assert(yt:read('*a'))
                        yt:close()

			if string.len(t["IP"]) ~= 0 then
				for line in io.lines(tmpdns) do
					for m,s in string.gmatch(line, "(%w+) (%d+%.%d+%.%d+%.%d+)") do
						t["DNS"..i] = s
						i = i + 1
					end
					if i == 4 then break end
				end
				os.execute('rm -rf '..tmpdns)
				if string.find(t["DNS1"]..","..t["DNS2"], t["DNS3"]) ~= nil then
					t["DNS3"] = ''
				end
				if string.find(t["DNS1"], t["DNS2"]) ~= nil then
					t["DNS2"] = ''
				end
			end

			yt = assert(io.popen('ifconfig pppoe-wan | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["IP"] = string.gsub(stryt, "\n", "")
			yt:close()

			yt = assert(io.popen('ifconfig pppoe-wan | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["Netmask"] = string.gsub(stryt, "\n", "")
			yt:close()

			-- local remote, no connection with pppoe server
			-- disconnected state
			--
			if string.match(t["IP"], "10.64.64.64") and string.match(t["Gateway"], "10.112.112.112") and string.match(t["Netmask"], "255.255.255.255") then
				t["IP"] = "0.0.0.0"
				t["Gateway"] = "0.0.0.0"
				t["Netmask"] = "0.0.0.0"
			end
		else
			t["ConnectionType"] = "pppoev6"
			yt = assert(io.popen('ifconfig pppoe-wan | grep -m1 "Scope:Global"| cut -d\/ -f1 | awk \'{print $3}\'', 'r'))
			stryt = assert(yt:read('*a'))
			if string.len(stryt) ~= 0 then
				t["IP"] = string.gsub(stryt, "\n", "")
			end
			yt:close()

			yt = assert(io.popen('route -A inet6 -n |grep \'::/0\' | grep \'UG[ \\t  ]\' | tail -n 1| awk \'{print $2}\'', 'r'))
			stryt = assert(yt:read('*a'))
			if string.len(stryt) ~= 0 then
				t["Gateway"] = string.lower(string.gsub(stryt, "\n", ""))
			end
			yt:close()

			yt = assert(io.popen('uci get network.wan6.proto', 'r'))
			stryt = assert(yt:read('*a'))
			if string.gsub(stryt, "\n", "") == '6rd' then
				t["ConnectionType"] = string.gsub(stryt, "\n", "")
			elseif string.gsub(stryt, "\n", "") == 'none' then
				t["ConnectionType"] = "na"
                        end
                        yt:close()


		end
	elseif objName == 'l2tp' then
		if ver == 'v4' then
			t["ConnectionType"] = "l2tp"
			cmd = 'objReq l2tp json'
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
			rt = json.decode(str)
			t["DNS1"] = ""
			t["DNS2"] = ""
			t["DNS3"] = ""
			r:close()

			yt = assert(io.popen('ifconfig l2tp-vpn | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["IP"] = string.gsub(stryt, "\n", "")
			yt:close()

			yt = assert(io.popen('ifconfig l2tp-vpn | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["Netmask"] = string.gsub(stryt, "\n", "")
			yt:close()

			i = 1
			if string.len(t["IP"]) ~= 0 then
				for line in io.lines('/tmp/resolv.conf.auto') do
					for m,s in string.gmatch(line, "(%w+) (%d+%.%d+%.%d+%.%d+)") do
						t["DNS"..i] = s
						i = i + 1
					end
					if i == 4 then break end
				end
				if string.find(t["DNS1"]..","..t["DNS2"], t["DNS3"]) ~= nil then
					t["DNS3"] = ''
				end
				if string.find(t["DNS1"], t["DNS2"]) ~= nil then
					t["DNS2"] = ''
				end
			end
		else
			t["ConnectionType"] = "na"
                end
	elseif objName == 'pptp' then
		if ver == 'v4' then
			t["ConnectionType"] = "pptp"
			cmd = 'objReq pptp json'
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
			rt = json.decode(str)
			t["DNS1"] = rt.PptpP.dns1
			t["DNS2"] = rt.PptpP.dns2
			t["DNS3"] = rt.PptpP.dns3
			r:close()

			yt = assert(io.popen('ifconfig pptp-vpn | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["IP"] = string.gsub(stryt, "\n", "")
			yt:close()

			yt = assert(io.popen('ifconfig pptp-vpn | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["Netmask"] = string.gsub(stryt, "\n", "")
			yt:close()

			i = 1
			if string.len(t["IP"]) ~= 0 then
				for line in io.lines('/tmp/resolv.conf.auto') do
					for m,s in string.gmatch(line, "(%w+) (%d+%.%d+%.%d+%.%d+)") do
						if i == 1 and string.len(t["DNS1"]) == 0 then
							t["DNS1"] = s
						elseif i == 2 and string.len(t["DNS2"]) == 0 then
							t["DNS2"] = s
						elseif i == 3 and string.len(t["DNS3"]) == 0 then
							t["DNS3"] = s
						end
						i = i + 1
					end
				end
				if string.find(t["DNS1"]..","..t["DNS2"], t["DNS3"]) ~= nil then
					t["DNS3"] = ''
				end
				if string.find(t["DNS1"], t["DNS2"]) ~= nil then
					t["DNS2"] = ''
				end
			end

			-- local remote, no connection with pptp server
			-- disconnected state
			--
			if string.match(t["IP"], "10.64.64.64") and string.match(t["Gateway"], "10.112.112.112") and string.match(t["Netmask"], "255.255.255.255") then
				t["IP"] = "0.0.0.0"
				t["Gateway"] = "0.0.0.0"
				t["Netmask"] = "0.0.0.0"
			end
		else
			t["ConnectionType"] = "na"
		end
	elseif objName == 'bridge' then
		if ver == 'v4' then
			t["ConnectionType"] = "bridge"
			cmd = 'objReq bridge json'
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
			rt = json.decode(str)
			r:close()
			yt = assert(io.popen('ifconfig br-lan | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["IP"] = string.gsub(stryt, "\n", "")
			yt:close()
			yt = assert(io.popen('ifconfig br-lan | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["Netmask"] = string.gsub(stryt, "\n", "")
			yt:close()

			i = 1
			for line in io.lines('/tmp/resolv.conf.auto') do
				for m,s in string.gmatch(line, "(%w+) (%d+%.%d+%.%d+%.%d+)") do
					t["DNS"..i] = s
					i = i + 1
				end
			end
		else
			t["ConnectionType"] = "dhcpv6"
			yt = assert(io.popen('ifconfig br-lan | grep \'inet6 addr\' | grep \'Global\' | tail -n 1 | awk \'{print $3}\' | cut -d\'/\' -f 1', 'r'))
			stryt = assert(yt:read('*a'))
			t["IP"] = string.gsub(stryt, "\n", "")
			yt:close()
		end
	elseif objName == 'wlanBridge' then
		if ver == 'v4' then
			t["ConnectionType"] = "wireless_bridge"
			cmd = 'objReq wlanBridge json'
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
			rt = json.decode(str)
			r:close()

			yt = assert(io.popen('ifconfig br-lan | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["IP"] = string.gsub(stryt, "\n", "")
			yt:close()
			yt = assert(io.popen('ifconfig br-lan | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
			stryt = assert(yt:read('*a'))
			t["Netmask"] = string.gsub(stryt, "\n", "")
			yt:close()

			i = 1
			for line in io.lines('/tmp/resolv.conf.auto') do
				for m,s in string.gmatch(line, "(%w+) (%d+%.%d+%.%d+%.%d+)") do
					t["DNS"..i] = s
					i = i + 1
				end
			end
		else
			t["ConnectionType"] = "dhcpv6"
			yt = assert(io.popen('ifconfig br-lan | grep \'inet6 addr\' | grep \'Global\' | tail -n 1 | awk \'{print $3}\' | cut -d\'/\' -f 1', 'r'))
			stryt = assert(yt:read('*a'))
			t["IP"] = string.gsub(stryt, "\n", "")
			yt:close()
		end
	end

	return t
end

function runtime.getVlan(ifvar)
	local cmd =''
	local r = ''
	local str = ''
	local t = {}
	local yt = ''
	local stryt= ''
	local rt = ''

	cmd = "ifconfig "..ifvar.." | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'"
	yt = assert(io.popen(cmd, 'r'))
	stryt = assert(yt:read('*a'))
	t["IP"] = string.gsub(stryt, "\n", "")
	yt:close()

	cmd = 'ifconfig '..ifvar..' | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\''
	yt = assert(io.popen(cmd, 'r'))
	stryt = assert(yt:read('*a'))
	t["Netmask"] = string.gsub(stryt, "\n", "")
	yt:close()

	yt = assert(io.popen('route -n | grep \'UG[ \\t]\' | awk \'{print $2}\'', 'r'))
	stryt = assert(yt:read('*a'))
	t["Gateway"] = string.gsub(stryt, "\n", "")
	yt:close()

	cmd = 'ifconfig '..ifvar..' | grep MTU | cut -d: -f2 | awk \'{print $1}\''
	yt = assert(io.popen(cmd, 'r'))
	stryt = assert(yt:read('*a'))
	t["MTU"] = string.gsub(stryt, "\n", "")
	yt:close()

    i = 1
    for line in io.lines('/tmp/resolv.conf.auto') do
        for m,s in string.gmatch(line, "(%w+) (%d+%.%d+%.%d+%.%d+)") do
            t["DNS"..i] = s
            i = i + 1
        end
    end

    cmd = 'ifstatus wan | jsonfilter -e @.data.leasetime'
    r = assert(io.popen(cmd, 'r'))
    str = assert(r:read('*a'))
    t["DHCPLeaseTime"] = string.gsub(str, "\n", "")
    r:close()

	cmd = 'objReq wan json'
	yt = assert(io.popen(cmd, 'r'))
	stryt = assert(yt:read('*a'))
	rt = json.decode(stryt)
	yt:close()

        -- static
	if rt.WanP.proto == '0' then
		t["ConnectionType"] = "static"
	else
		t["ConnectionType"] = "dhcp"
	end

	return t
end

function runtime.getLan(objName, ver)
	local cmd
	local r
	local str
	local rt

	if objName == 'wan' then
		cmd = 'objReq '..objName..' json'
		r = (io.popen(cmd, 'r'))
		str = assert(r:read('*a'))
		rt = json.decode(str)
		r:close()

		-- bridge
		if rt.WanP.proto == '5' then
			ret = runtime.getWanProtoStatus('bridge', ver)
		-- wifi bridge/wlanBridge
		elseif rt.WanP.proto == '6' then
			ret = runtime.getWanProtoStatus('wlanBridge', ver)
		-- pppoe
		elseif rt.WanP.proto == '2' then
			ret = runtime.getWanProtoStatus('pppoe', ver)
		-- l2tp
		elseif rt.WanP.proto == '3' then
			ret = runtime.getWanProtoStatus('l2tp', ver)
		-- pptp
		elseif rt.WanP.proto == '4' then
			ret = runtime.getWanProtoStatus('pptp', ver)
		else
			cmd = 'objReq vlanEnable json'
			r = assert(io.popen(cmd, 'r'))
			str = assert(r:read('*a'))
			rt = json.decode(str)
			r:close()

			if rt.VlanEnableP.vlanEnable == '1' and ver == 'v4' then
				cmd = 'uci get network.wan.ifname'
				r = assert(io.popen(cmd, 'r'))
				str = assert(r:read('*a'))
				r:close()
				ret = runtime.getVlan(string.gsub(str, "\n", ""))
			else
				cmd = 'objReq wan json'
				r = assert(io.popen(cmd, 'r'))
				str = assert(r:read('*a'))
				rt = json.decode(str)
				r:close()

				-- static
				if rt.WanP.proto == '0' then
					ret = runtime.getWanProtoStatus('static', ver)
				-- dhcp
				elseif rt.WanP.proto == '1' then
					ret = runtime.getWanProtoStatus('dhcp', ver)
				end
			end
                end
	end

	return ret
end


function runtime.InternetConnection(arg)
	local r = {}
	local v = {}
	local jrt = {}

	r=runtime.getLan('wan', 'v4')
	v["IPv4"] = r

	r=runtime.getLan('wan', 'v6')
	v["IPv6"] = r
	jrt["InternetConnection"] = v

	return json.encode(jrt)
end

function runtime.LocalNetwork(arg)
	local rt = {}
	local jrt = {}
	local prt = {}
	local se = ''

	local cmd = 'ifconfig br-lan | grep HWaddr | awk \'{print $5}\''
	local p = assert(io.popen(cmd, 'r'))
	local strp = assert(p:read('*a'))
	rt["LocalMAC"] = string.gsub(strp, "\n", "")
	p:close()


	local cmd = 'objReq wan json'
	local w= assert(io.popen(cmd, 'r'))
	local str = assert(w:read('*a'))
	local k = json.decode(str)

        -- 0:static, 1:dhcpc, 2:pppoe, 3:l2tp, 4:pptp, 5:bridge, 6:wifi bridge
        w:close()

	if k.WanP.proto == '5' or k.WanP.proto == '6' then
		p = assert(io.popen('ifconfig br-lan | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
		strp = assert(p:read('*a'))
		rt["IP"] = string.gsub(strp, "\n", "")
		p:close()

		p = assert(io.popen('route -n | grep \'UG[ \\t]\' | awk \'{print $2}\'', 'r'))
		strp = assert(p:read('*a'))
		rt["Gateway"] = string.gsub(strp, "\n", "")
		p:close()

		p = assert(io.popen('ifconfig br-lan | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
		strp = assert(p:read('*a'))
		rt["Netmask"] = string.gsub(strp, "\n", "")
		p:close()

	else
		p = assert(io.popen('uci get network.lan.ipaddr', 'r'))
		strp = assert(p:read('*a'))
		rt["IP"] = string.gsub(strp, "\n", "")
		p:close()

		p = assert(io.popen('route -n | grep \'UG[ \\t]\' | awk \'{print $2}\'', 'r'))
		strp = assert(p:read('*a'))
		rt["Gateway"] = string.gsub(strp, "\n", "")
		p:close()

		p = assert(io.popen('uci get network.lan.netmask', 'r'))
		strp = assert(p:read('*a'))
		rt["Netmask"] = string.gsub(strp, "\n", "")
		p:close()
	end

	p = assert(io.popen('ifconfig br-lan |grep "inet6 addr:" | grep "Scope:Link"| cut -d\/ -f1 | awk \'{print $3}\'', 'r'))
	strp = assert(p:read('*a'))
	rt["IPv6LinkLocalAddress"] = string.gsub(strp, "\n", "")
	p:close()

	rt["Prefix"] = "N/A"
	p = assert(io.popen('ifconfig br-lan | grep \"Scope:Global\" | awk \'{print $3}\' | tail -n 1', 'r'))
	strp = assert(p:read('*a'))
	if strp ~= "" then
		rt["Prefix"] = string.gsub(strp, "\n", "")
	end
	p:close()

	jrt["LocalNetwork"] = rt

	p = assert(io.popen('objReq dhcps json', 'r'))
	strp = assert(p:read('*a'))
	local dh = json.decode(strp)
	rt = {}
	if k.WanP.proto == '5' or k.WanP.proto == '6' then
		rt["Server"] = 'Disabled'
	else
		if dh.DhcpsP.enable == '1' then
			rt["Server"] = 'Enabled'
		else
			rt["Server"] = 'Disabled'
		end
	end
	rt["StartIP"] = dh.DhcpsP.startIp
	rt["EndIP"] = ''

	local i = 0
	string.split = function(s, p)
		local rt= {}
		string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
		return rt
	end

	local list = string.split(dh.DhcpsP.startIp, '.')
	for _, s in ipairs(list) do
		i = i + 1
		if i == 4 then
			local u = s+dh.DhcpsP.maxClient-1
			rt["EndIP"] = rt["EndIP"]..u
		else
			rt["EndIP"] = rt["EndIP"]..s.."."
		end
	end

	jrt["DHCP"] = rt
	prt["LocalNetwork"] = jrt

	p:close()
	return json.encode(prt)
end

function runtime.Wifi5G(arg)
	local rt = {}
	local jrt = {}
	local cmd = 'objReq wlanBasic json'
	local r = assert(io.popen(cmd, 'r'))
	local str = assert(r:read('*a'))
	local k = json.decode(str)
	local index = 1
	local iname = k.WlanBasicT[index].ifname
	if iname == 'rai0' then
		index = 1
	else
		iname = 'rai0'
		index = 2
	end

	if k.WlanBasicT[index].enable == '0' then
		rt["Mode"] = 'disable'
	else
		rt["Mode"] = k.WlanBasicT[index].wifimode
	end
	rt["SSID"] = k.WlanBasicT[index].ssid
	rt["ChannelWidth"] = k.WlanBasicT[index].bw
	rt["SSIDHiden"] = k.WlanBasicT[index].hiddenAP
	r:close()

	cmd = 'iwconfig '..iname..' | grep Channel | awk \'{print $2}\' | cut -d\'=\' -f 2'
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))
	rt["Channel"] = string.gsub(str, "\n", "")
	r:close()

	cmd = 'objReq wlanSecurity json'
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))
	k = json.decode(str)
	rt["Security"] = k.WlanSecurityT[index].authtype
	r:close()

	cmd = 'ifconfig '..iname..' | grep HWaddr | awk \'{print $5}\''
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))
	rt["MAC"] = string.gsub(str, "\n", "")
	r:close()

    local emenable
    local emrole
    cmd = 'objReq easyMeshBasic json'
    r = assert(io.popen(cmd, 'r'))
    str = assert(r:read('*a'))
    k = json.decode(str)
    emenable = k.EasyMeshBasicP.enable
    emrole = k.EasyMeshBasicP.deviceRole
    r:close()

    if emenable == '1' and emrole == '2' then
        cmd = 'iwconfig '..iname..' | grep ESSID | awk \'{print $4}\' | cut -d\'"\' -f 2'
        r = assert(io.popen(cmd, 'r'))
        str = assert(r:read('*a'))
        r:close()
        rt["Security"] = "WPA2PSK"
        rt["SSID"] = string.gsub(str, "\n", "")
    end

	jrt["Wifi5G"] = rt
	return json.encode(jrt)
end

function runtime.Wifi2G(arg)
	local rt = {}
	local jrt = {}
	local cmd = 'objReq wlanBasic json'
	local r = assert(io.popen(cmd, 'r'))
	local str = assert(r:read('*a'))
	local k = json.decode(str)
	local index = 1
	local iname = k.WlanBasicT[index].ifname
	if iname == 'ra0' then
		index = 1
	else
		iname = 'ra0'
		index = 2
	end

	if k.WlanBasicT[index].enable == '0' then
		rt["Mode"] = 'disable'
	else
		rt["Mode"] = k.WlanBasicT[index].wifimode
	end

	rt["SSID"] = k.WlanBasicT[index].ssid
	rt["ChannelWidth"] = k.WlanBasicT[index].bw
	rt["SSIDHiden"] = k.WlanBasicT[index].hiddenAP
	r:close()

	cmd = 'iwconfig '..iname..' | grep Channel | awk \'{print $2}\' | cut -d\'=\' -f 2'
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))
	rt["Channel"] = string.gsub(str, "\n", "")
	r:close()

	cmd = 'objReq wlanSecurity json'
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))
	k = json.decode(str)
	rt["Security"] = k.WlanSecurityT[index].authtype
	r:close()

	cmd = 'ifconfig '..iname..' | grep HWaddr | awk \'{print $5}\''
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))
	rt["MAC"] = string.gsub(str, "\n", "")
	r:close()

	local emenable
	local emrole
	cmd = 'objReq easyMeshBasic json'
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))
	k = json.decode(str)
	emenable = k.EasyMeshBasicP.enable
	emrole = k.EasyMeshBasicP.deviceRole
	r:close()

	if emenable == '1' and emrole == '2' then
		cmd = 'iwconfig '..iname..' | grep ESSID | awk \'{print $4}\' | cut -d\'"\' -f 2'
		r = assert(io.popen(cmd, 'r'))
		str = assert(r:read('*a'))
		r:close()
		rt["Security"] = "WPA2PSK"
		rt["SSID"] = string.gsub(str, "\n", "")
	end

	jrt["Wifi2G"] = rt
	return json.encode(jrt)
end

function runtime.splitrouteinfo(linestr, sep)
        local t={}
	local rt={}
        local keyt={"dest","gw","mask","if", "hopn"}

        sep = sep or '%s'
        local i = 1
	string.gsub(linestr, '[^%s*]+', function(w) table.insert(rt, w) end )

	t[keyt[1]] = rt[1]
	t[keyt[2]] = rt[2]
	t[keyt[3]] = rt[3]
	local p = assert(io.popen('uci get network.wan.ifname', 'r'))
	local strp = string.gsub(assert(p:read('*a')), "\n", "")
	p:close()
	if rt[8] == strp then
		t[keyt[4]] = "wan"
	else
		t[keyt[4]] = "lan"
	end
	t[keyt[5]] = "1"

        return t
end

function runtime.showRouteT()
        local rt = {}
        local crt = {}
        local jrt = {}
        local s = ''
        local f = assert(io.popen("/sbin/route -n", 'r'))
	local skipline = 1
        while true do
                s = f:read()
                if s == nil then
                        break
                end
		if skipline > 2 then
			print('Parse '..s)
			rt = runtime.splitrouteinfo(s, ' ')
			table.insert(crt, rt)
		end
		skipline=skipline+1
        end
	f:close()

        --Set to final json
        jrt["showRouteT"] = crt

        return json.encode(jrt)
end

function runtime.getfileItem(filepath, key)
	local ret = 0
	local file = io.open(filepath, "r")
	if file then
		ret = file:read()
		file:close()

		if key ~= nil then
			--print("Get key= "..key)
			local r, k = pcall(json.decode, ret)
			if r then
				--PrintTable(k)
				ret = k[key]
			else
				ret = 0
			end
		end
	end
	return ret
end


function runtime.version_compare(now, new)
	local now_rt = {}
	local new_rt = {}
	local ret=0
	sep = sep or '%s'
	string.gsub(now, '[^.*]+', function(w) table.insert(now_rt, w) end )
	string.gsub(new, '[^.*]+', function(w) table.insert(new_rt, w) end )

	for i = 1, 4 do
		if tonumber(now_rt[i]) then
			if tonumber(new_rt[i]) > tonumber(now_rt[i]) then
				ret=1
				break
			elseif tonumber(new_rt[i]) < tonumber(now_rt[i]) then
				break
			end
		else
			ret=1
			print("Force to upgrade because local version not number!!!")
			break
		end
	end
	print("Check version status is "..ret)

	return ret
end

function runtime.checkFW(pt)
        local ret = '"NOK"'
        local filepath = "/tmp/checkfw"
        local getversion = ""
        local runversion = runtime.getfileItem("/etc/version", nil)
        print("Get current version "..runversion)

        if pt ~= nil then
                os.execute("checkFW.sh upgrade &")
                ret = '"OK"'
        else
                --Checking from fw server
                if runtime.getfileItem(filepath, "version") == 0 then
                        os.execute("/usr/bin/checkFW.sh")
                end
                getversion=runtime.getfileItem(filepath, "version")
                print("Get server version= "..getversion)
                ret = '{"checkFW":{"version":"'..getversion..'", "status":"'..runtime.version_compare(runversion, getversion)..'", "fwstatus":"'..runtime.getfileItem("/tmp/fwperc", nil)..'"}}'
        end
        return ret
end

function runtime.wpsProcess(pt)
	local ret = '"OK"'
	
      	print("wpsProcess")
       

    if pt["Mode"] == 'PBC' then   
   		os.execute("wps_action.sh PBC &")
        
	elseif pt["Mode"] == 'PIN' and pt["PinCode"] ~= nil then
    
        cmd = 'wps_action.sh PIN '..pt["PinCode"]..' &'
        os.execute(cmd)
        
    elseif pt["Mode"] == 'STOP' then
        print("wpsProcess STOP")
        
        cmd = 'ps | grep wps_action.sh | grep -v grep | awk \'{print $1}\' | xargs kill'
        os.execute(cmd)
        
	else
        print("wpsProcess Fail")
	end

       return ret
end

function runtime.wscMonitor(arg)


	local rt = {}
	local jrt = {}
	local cmd = 'wsc_monitor -i ra0'
	local r = assert(io.popen(cmd, 'r'))
	local str = assert(r:read('*a'))


	rt["ra0"] = string.gsub(str, "\n", "")

	r:close()
    
	cmd = 'wsc_monitor -i rai0'
	r = assert(io.popen(cmd, 'r'))
	str = assert(r:read('*a'))


	rt["rai0"] = string.gsub(str, "\n", "")

	r:close()

	jrt["wscMonitor"] = rt

	return json.encode(jrt)
end

function runtime.dhcpAction(da)
	local ret = '"NOK"'
	local jrt = {}
	--printd("dhcpAction action = " ..da.dhcpAction.action)
	if da ~= nil then
		if da.target == 'v4' then
			if da.action == 'release' then
				os.execute('killall -SIGUSR2 udhcpc')
				os.execute('ifdown -w wan')
				ret = '"OK"'
			else
				--os.execute('killall -SIGUSR1 udhcpc')
				os.execute('ifdown -w wan; ifup -w wan')
				ret = '"OK"'
			end
		else 
			if da.action == 'release' then
				os.execute('ifdown -w wan6')
				ret = '"OK"'
			else
				os.execute('ifdown -w wan6; ifup -w wan6')
				ret = '"OK"'
			end
		end
	else
		ret = '"NOK"'
	end

	jrt["dhcpAction"] = ret
	--return json.encode(jrt)
	return ret
end

function runtime.macClone(mc)
	local ret = '"NOK"'
	local jrt = {}

	if mc ~= nil then
		local cmd = 'cat /proc/net/arp | grep \"'..mc.ip..'\" | awk \'{print $4}\''
		local r = assert(io.popen(cmd, 'r'))
		local str = assert(r:read('*a'))

		ret = string.gsub(str, "\n", "")
	else
		ret = '"NOK"'
	end
	jrt["mac"] = ret
	return json.encode(jrt)
end

function runtime.vpnAction(va)
	local ret = 'NOK'
	local rt = {}
	local jrt = {}
	local t = {}
	local cmd
	local w
	local str
	local k
	local ifvar

	if va ~= nil then
		if va["action"] == 'connect' then
			-- connect
			if va["type"] == 'pppoe' then
				os.execute('ifdown wan ; ifup wan')
			else
				os.execute('ifdown vpn ; ifup vpn')
			end
		elseif va["action"] == 'disconnect' then
			-- disconnect
			if va["type"] == 'pppoe' then
				os.execute('ifdown wan')
				os.execute('uci -q delete network.wan.dns ; uci commit network')
			else
				os.execute('ifdown vpn')
			end
		end
	else
		cmd = 'objReq wan json'
		w = assert(io.popen(cmd, 'r'))
		str = assert(w:read('*a'))
		k = json.decode(str)

		-- 0:static, 1:dhcpc, 2:pppoe, 3:l2tp, 4:pptp, 5:bridge, 6:wifi bridge
		if k.WanP.proto == '2' then
			rt["type"] = 'pppoe'
			ifvar = 'pppoe-wan'
		elseif k.WanP.proto == '3' then
			rt["type"] = 'l2tp'
			ifvar = 'l2tp-vpn'
		elseif k.WanP.proto == '4' then
			rt["type"] = 'pptp'
			ifvar = 'pptp-vpn'
		else
			rt["type"] = 'nil'
			ifvar = 'nil'
		end
		w:close()

		cmd = 'ifconfig ' ..ifvar..' 2&>1 > /dev/null ; echo $?'
		w = assert(io.popen(cmd, 'r'))
		str = assert(w:read('*a'))
		w:close()

		if string.gsub(str, "\n", "") == '0' then
			w = assert(io.popen('ifconfig '..ifvar..' | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
			str = assert(w:read('*a'))
			t["IP"] = string.gsub(str, "\n", "")
			w:close()

			w = assert(io.popen('ifconfig '..ifvar..' | grep \'Mask\' | cut -d: -f4 | awk \'{print $1}\'', 'r'))
			str = assert(w:read('*a'))
			t["Netmask"] = string.gsub(str, "\n", "")
			w:close()

			w = assert(io.popen('route -n |grep \'0.0.0.0\' | grep \'UG[ \\t]\' | awk \'{print $2}\'', 'r'))
			str = assert(w:read('*a'))
			t["Gateway"] = string.gsub(str, "\n", "")
			w:close()

			-- local remote, no connection with pppoe server
			-- disconnected state
			--
			if string.match(t["IP"], "10.64.64.64") and string.match(t["Gateway"], "10.112.112.112") and string.match(t["Netmask"], "255.255.255.255") then
				ret = 'NOK'
			else
				ret = 'OK'
			end
		else
			ret = 'NOK'
		end
	end

	rt["status"] = ret
	rt["action"] = ''
	jrt["vpnAction"] = rt
	return json.encode(jrt)
end

function runtime.v6rdAction(va)
	local ret = 'NOK'
	local rt = {}
	local jrt = {}
	local cmd, r, str

	if va ~= nil then
		if va["action"] == 'reconnect' then
			-- reconnect
			os.execute('ifdown -w wan; ifup -w wan')
			os.execute('ifdown -w wan6; ifup -w wan6')
			ret = 'OK'
                end
        else
		cmd = 'ifstatus wan6 | jsonfilter -e @.up'
		r = assert(io.popen(cmd, 'r'))
		str = assert(r:read('*a'))
		r:close()
		up = string.gsub(str, "\n", "")
		if up == 'true' then
			ret = 'OK'
		else
			ret = 'NOK'
		end
	end

	rt["action"] = ''
	rt["status"] = ret
	jrt["v6rdAction"] = rt
	return json.encode(jrt)
end

function runtime.ddnsStatus(ds)
	local ret = 'NOK'
	local rt = {}
	local jrt = {}
	local cmd, w, k, str, ip, sy, ifvar
	local mx = "NOCHG"
	local bmx = "NOCHG"
	local wcd = "false"
	local logddns = "/tmp/.logddns"

	cmd = 'objReq wan json'
	w = assert(io.popen(cmd, 'r'))
	str = assert(w:read('*a'))
	k = json.decode(str)

	-- 0:static, 1:dhcpc, 2:pppoe, 3:l2tp, 4:pptp, 5:bridge, 6:wifi bridge
	if k.WanP.proto == '2' then
		ifvar = 'pppoe-wan'
	elseif k.WanP.proto == '3' then
		ifvar = 'l2tp-vpn'
	elseif k.WanP.proto == '4' then
		ifvar = 'pptp-vpn'
	else
		ifvar = 'eth1'
	end
	w:close()

	w = assert(io.popen('ifconfig '..ifvar..' | grep \'inet addr\' | cut -d: -f2 | awk \'{print $1}\'', 'r'))
	str = assert(w:read('*a'))
	ip = string.gsub(str, "\n", "")
	w:close()

	cmd = 'objReq Ddns json'
	w = assert(io.popen(cmd, 'r'))
	str = assert(w:read('*a'))
	k = json.decode(str)
	w:close()

	-- [status]
	--
	-- 0: DDNS function is disabled, 1: DDNS is updated successfully 2: Authorization fails (username or passwords)
	-- 3: Invalid Host Name, 4: Connecting to server, 5: No internet connection
	-- 6: DDNS is updated successfully. Operation complete

	if k.DdnsP.enable == '0' then
		rt["status"] = '0'
	else
		rt["status"] = '4'
		cmd = 'ping -q -c 2 -w 2 8.8.8.8 > /dev/null 2>&1; echo $?'
		w = assert(io.popen(cmd, 'r'))
		str = assert(w:read('*a'))
		w:close()

		if string.gsub(str, "\n", "") == '1' then
			-- no connection ability
			rt["status"] = '5'
		else
			if k.DdnsP.provider == 'no-ip.com' then
				-- https://www.noip.com/docs/crosswalk.pdf
				-- System, Mail Exchange, Backup MX, Wildcard will be ignored by no-ip.com
				-- Note: Excessive nochg responses may result in your client being blocked.
				--
				--
				-- cmd = 'curl -X GET http://dynupdate.no-ip.com/nic/update > /dev/null 2>&1 > '..logddns
                cmd = 'curl --user '..k.DdnsP.username..':'..k.DdnsP.password..' \'http://dynupdate.no-ip.com/nic/update?hostname='..k.DdnsP.hostname..'&myip='..ip..'\' > /dev/null 2>&1 > '..logddns
				os.execute(cmd)
				cmd = 'cat '..logddns..' | awk \'{print $1}\''
				w = assert(io.popen(cmd, 'r'))
				str = assert(w:read('*a'))
				w:close()
				os.execute("rm -rf "..logddns)

				--w = assert(io.popen('curl -X GET http://ip1.dynupdate.no-ip.com/', 'r'))
				--str = assert(w:read('*a'))
				--ip = string.gsub(str, "\n", "")
				--w:close()
			elseif k.DdnsP.provider == 'DynDNS.org' then
				if k.DdnsP.wildcard == '1' then
					wcd = 'true'
				end
				if string.len(k.DdnsP.mailex) ~= 0 then
					mx = k.DdnsP.mailex
				end
				if k.DdnsP.backupmailex == '1' then
					bmx = "YES"
				end

				-- 0:Custom, 1:Static, 2:Dynamic
				if k.DdnsP.system == '0' then
					sy = "custom"
				elseif k.DdnsP.system == '1' then
					sy = "static"
				elseif k.DdnsP.system == '2' then
					sy = "dynamic"
				end

				--cmd = 'curl -o '..logddns..' http://checkip.dyndns.com/ > /dev/null 2>&1'
				--os.execute(cmd)
				--cmd = 'cat '..logddns..' | awk \'{print $6}\' | cut -d\'<\' -f 1'
				--w = assert(io.popen(cmd, 'r'))
				--str = assert(w:read('*a'))
				--ip = string.gsub(str, "\n", "")
				--w:close()

				--cmd = 'curl -X GET http://members.dyndns.org/nic/update > /dev/null 2>&1 > '..logddns
				--cmd = 'curl -X GET http://'..k.DdnsP.username..':'..k.DdnsP.password..'@members.dyndns.org/nic/update?hostname='..k.DdnsP.hostname..'&myip='..ip..'&wildcard='..wcd..'&mx='..mx..'&backmx='..bmx..'&dyndns='..sy..' > /dev/null 2>&1 > '..logddns
				cmd = 'curl --max-time 2 -X GET http://'..k.DdnsP.username..':'..k.DdnsP.password..'@members.dyndns.org/nic/update?hostname='..k.DdnsP.hostname..'&myip='..ip..'&wildcard='..wcd..'&mx='..mx..'&backmx='..bmx..'&dyndns='..sy..' > /dev/null 2>&1'

				os.execute(cmd)
				w = assert(io.popen(cmd, 'r'))
				str = assert(w:read('*a'))
				w:close()
				cmd = 'echo '..str..' | awk \'{print $1}\''
				os.execute(cmd)
				w = assert(io.popen(cmd, 'r'))
				str = assert(w:read('*a'))
				w:close()
			end

			if string.gsub(str, "\n", "") == 'good' then
				rt["status"] = '6'
			elseif string.gsub(str, "\n", "") == 'nochg' then
				rt["status"] = '1'
			elseif string.gsub(str, "\n", "") == 'badauth' then
				rt["status"] = '2'
			elseif string.gsub(str, "\n", "") == 'nohost' then
				rt["status"] = '3'
			elseif string.gsub(str, "\n", "") == 'notfqdn' then
				rt["status"] = '3'
			end
		end
	end

	rt["ip"] = ip
	jrt["ddnsStatus"] = rt
	return json.encode(jrt)
end

function runtime.systemLog(sy)
	local jrt = {}
	local rt = {}
	local t = {}
	local logdhcp = "/var/log/log.hummer"
	local klog = "/var/log/klog.hummer"
	local klog0 = "/var/log/klog.hummer.0"
	local sefp = "/tmp/log/lighttpd/login_status.log"
	local cmd
	local result = ""
	local i = 0
	local j = 0
	local k = 0
	local file_found

	rt["data"] = ''
	if sy ~= nil then
		if sy["action"] == "clear" then
			if sy["type"] == 'dhcp' then
				cmd = "sed -i \'/DHCP/d\' "..logdhcp
				os.execute(cmd)
			elseif sy["type"] == 'security' then
				cmd = "echo > "..sefp
				os.execute(cmd)
			elseif sy["type"] == 'outgoing' then
				cmd = "sed -i \'/Outbound/d\' "..klog
				os.execute(cmd)
				cmd = "sed -i \'/Outbound/d\' "..klog0
				os.execute(cmd)
			elseif sy["type"] == 'incoming' then
				cmd = "sed -i \'/Inbound/d\' "..klog
				os.execute(cmd)
				cmd = "sed -i \'/Inbound/d\' "..klog0
				os.execute(cmd)
			end
		else
			if sy["type"] == 'dhcp' then
				local sep = ' '
				local f0 = io.open(logdhcp, "r")
				if f0 == nil then
					os.execute("echo > "..logdhcp)
				end
				for line in io.lines(logdhcp) do
					i = 0
					result = ""
					if string.match(line, "DHCPREQUEST") then
						for field,s in string.gmatch(line, "([^"..sep.."]*)("..sep.."?)") do
							if i == 0 then
								result = field.." "
							elseif i == 1 then
								result = result..field.." "..os.date("%Y").." "
							elseif i == 2 then
								result = result..field.." recieved REQUEST from "
							elseif i == 6 then
								result = result..field
							end
							i = i + 1
						end
					end
					if string.match(line, "DHCPNAK") then
						for field,s in string.gmatch(line, "([^"..sep.."]*)("..sep.."?)") do
							if i == 0 then
								result = field.." "
							elseif i == 1 then
								result = result..field.." "..os.date("%Y").." "
							elseif i == 2 then
								result = result..field.." sending NAK to "
							elseif i == 5 then
								result = result..field
							end
							i = i + 1
						end
					end

					if string.match(line, "DHCPACK") then
						for field,s in string.gmatch(line, "([^"..sep.."]*)("..sep.."?)") do
							if i == 0 then
								result = field.." "
							elseif i == 1 then
								result = result..field.." "..os.date("%Y").." "
							elseif i == 2 then
								result = result..field.." sending ACK to "
							elseif i == 5 then
								result = result..field
							end
							i = i + 1
						end
					end
					if string.len(result) ~= 0 then
						rt["data"] = rt["data"]..result.."\n"
					end
				end
			elseif sy["type"] == 'security' then
				if file_found == nil then
					cmd = "touch "..sefp
					os.execute(cmd)
				end

				for line in io.lines(sefp) do
					result = result..line.."\n"
				end
				rt["data"] = result
			elseif sy["type"] == 'outgoing' then
				local sep = ' '
				local f0 = io.open(klog0, "r")
				if f0 ~= nil then
					allf = {klog, klog0}
				else
					allf = {klog}
				end
				for i, e in ipairs(allf) do
					for line in io.lines(e) do
						i = 0
						local dt = {}
						dt["lanip"] = ''
						dt["dst"] = ''
						dt["port"] = ''
						if string.match(line, "Outbound") then
							local src = string.match(line, 'SRC=%d+%.%d+%.%d+%.%d+')
							local dst = string.match(line, 'DST=%d+%.%d+%.%d+%.%d+')
							local dpt = string.match(line, 'DPT=%d+')

							if src ~= nil then
								for m,f in string.gmatch(src, "([^=]*)(=?)") do
									if i == 1 then
										dt["lanip"] = m
									end
									i = i + 1
								end
							end
							i = 0

							if dst ~= nil then
								for m,f in string.gmatch(dst, "([^=]*)(=?)") do
									if i == 1 then
										dt["dst"] = m
										end
									i = i + 1
								end
							end
							i = 0

							if dpt ~= nil then
								for m,f in string.gmatch(dpt, "([^=]*)(=?)") do
									if i == 1 then
										dt["port"] = m
									end
									i = i + 1
								end
							else
								dt["port"] = '0'
							end
						end
						if string.len(dt["lanip"]) ~= 0 or string.len(dt["dst"]) ~= 0 or string.len(dt["port"]) ~= 0 then
							--print("lanip ="..dt["lanip"].." dst ="..dt["dst"].." port = "..dt["port"])
							table.insert(t, dt)
						end
					end
				end
				rt["data"] = t
			elseif sy["type"] == 'incoming' then
				local sep = ' '
				local f0 = io.open(klog0, "r")
				if f0 ~= nil then
					allf = {klog, klog0}
				else
					allf = {klog}
				end
				for i, e in ipairs(allf) do
					for line in io.lines(e) do
						i = 0
						local dt = {}
						dt["srcip"] = ''
						dt["port"] = ''
						if string.match(line, "Inbound") then
                                                        local src = string.match(line, 'SRC=%d+%.%d+%.%d+%.%d+')
                                                        local dpt = string.match(line, 'DPT=%d+')

							if src ~= nil then
								for m,f in string.gmatch(src, "([^=]*)(=?)") do
									if i == 1 then
										dt["srcip"] = m
									end
									i = i + 1
								end
							end

							i = 0
							if dpt ~= nil then
								for m,f in string.gmatch(dpt, "([^=]*)(=?)") do
									if i == 1 then
										dt["port"] = m
									end
									i = i + 1
								end
							else
								dt["port"] = '0'
							end
						end
						if string.len(dt["srcip"]) ~= 0 or string.len(dt["port"]) ~= 0 then
							--print("srcip ="..dt["srcip"].." port = "..dt["port"])
							table.insert(t, dt)
						end
					end
					rt["data"] = t
				end
			end
		end
	end

	rt["type"] = sy["type"]
	jrt["systemLog"] = rt
	return json.encode(jrt)
end


function runtime.autowan(au)
	local jrt = {}
	local rt = {}
	local cmd, w, str, result
	-- curl -X POST http://127.0.0.1:80/API/info -d '{"autowan":{"detectType":"1","enable":"1"}}'
	-- detect type: 1:dhcpc, 2:pppoe
	cmd = "/usr/bin/dhcp-discovery -i eth1 -t 2"
	w = assert(io.popen(cmd, 'r'))
	str = assert(w:read('*a'))
	w:close()
	result = '0'
	if string.match(str, "DHCP ok") then
		result = '1'
	else
		cmd = "/usr/sbin/pppoe-discovery -I eth1 -D /tmp/autoWan.log"
		os.execute(cmd)
		for line in io.lines("/tmp/autoWan.log") do
			if string.match(line, "PADO") then
				result = '2'
				os.execute("touch /tmp/.firstWizard")
				break
			else
				-- Timeout waiting for PADO packets
				result = '0'
			end
		end
		os.execute("rm -rf /tmp/autoWan.log")
	end

	rt["detectType"] = result
	rt["enable"] = '1'
	jrt["autowan"] = rt
	return json.encode(jrt)
end

function runtime.dhcp6cDuid()
    local jrt = {}

    cmd = 'ifconfig eth1 | grep HWaddr | awk \'{print $5}\''
    r = assert(io.popen(cmd, 'r'))
    str = assert(r:read('*a'))
    mac = string.gsub(str, "\n", "")
    duid = '00:03:00:01:' .. mac

    jrt["duid"] = duid
    return json.encode(jrt)
end

function runtime.hosts()
    local jrt = {}
    local hosts = {}
    local key = {"mac", "hostname"}

    cmd = '/bin/get_hosts.sh > /tmp/hosts.info'
    os.execute(cmd)

    for line in io.lines('/tmp/hosts.info') do
        local str, w
        local host = {}
        local macaddr = line:match("(%S+)")
        local hostname = line:gsub("^.-%s", "", 1)

        cmd = 'grep "\\"' .. hostname .. '\\"" /tmp/mesh_msg.txt'
        w = assert(io.popen(cmd, 'r'))
        str = assert(w:read('*a'))
        w:close()

        if str == nil or str == '' then
            host["mac"] = macaddr
            host["hostname"] = hostname

            table.insert(hosts, host)
        end
    end

    jrt["hosts"] = hosts
    return json.encode(jrt)
end

function runtime.emailReg(pt)
	local ret = '"NOK"'
	local keyt = {}
	local sendstr = ''
	local clientId='CEDB0063-0200-4797-9009-F195442F253A'
	local headstr="-H 'Content-Type:application/json; charset=UTF-8' -H Accept:application/json -H X-Linksys-Client-Type-Id:"..clientId
	if pt ~= nil then
		keyt["serialNumber"] = runtime.getfileItem("/tmp/devinfo/serial_number", nil)
		keyt["modelNumber"] = runtime.getfileItem("/tmp/devinfo/modelNumber", nil)
		keyt["sku"] = keyt["modelNumber"].."-"..runtime.getfileItem("/tmp/devinfo/cert_region", nil)
		keyt["emailAddress"] = pt["email"]
		keyt["optIn"] = pt["future"]
		keyt["hardwareVersion"] = runtime.getfileItem("/tmp/devinfo/hw_version", nil)
		keyt["macAddress"] = runtime.getfileItem("/tmp/devinfo/hw_mac_addr", nil)
		--PrintTable(keyt)
		sendstr = '{"productRegistration":'..json.encode(keyt)..'}'
                --print("Send cmd= [curl "..headstr.." -X POST https://cloud.linksyssmartwifi.com/product-service/rest/productRegistrations -d '"..sendstr.."']")
		os.execute("curl "..headstr.." -X POST https://cloud.linksyssmartwifi.com/product-service/rest/productRegistrations -d '"..sendstr.."' > /tmp/emailRegRet")
		os.execute("cat /tmp/emailRegRet | cut -d \'\"\' -f 6 > /tmp/emailReg")
		local getregid=runtime.getfileItem("/tmp/emailReg", nil)
		if getregid ~= nil then
			os.execute('objReq account setparam 0 email '..pt["email"]..'+'..getregid..' && gnvram commit')
			ret ='"OK"'
		end
	end
	return ret
end

function runtime.getPolicy(arg)
	local ret = '"NOK"'
	local webpath="https://www.belkin.com/us/privacypolicy/"
	local localptah="/www/policy/public_policy.html"
	os.execute("curl --connect-timeout 1 "..webpath.." > "..localptah)
	ret = '{"getPolicy":{"status":"1"}}'
	return ret
end

function runtime.connStatus(arg)
	local ret = '"NOK"'
	local pingserver1="8.8.8.8"
	local pingserver2="9.9.9.9"
	local cmd = 'ping -q -c2 -w2 '..pingserver1..' > /dev/null 2>&1; echo $?'
	local w = assert(io.popen(cmd, 'r'))
	local str = assert(w:read('*a'))
	w:close()

	if string.gsub(str, "\n", "") == '1' then
		cmd = 'ping -q -c2 -w2 '..pingserver2..' > /dev/null 2>&1; echo $?'
		w = assert(io.popen(cmd, 'r'))
		str = assert(w:read('*a'))
		w:close()
		if string.gsub(str, "\n", "") == '1' then
			ret = '{"connStatus":{"status":"0"}}'
		else
			ret = '{"connStatus":{"status":"1"}}'
		end
	else
		ret = '{"connStatus":{"status":"1"}}'
	end
	return ret
end

function runtime.wlanbridgeTest(arg)

    local jrt = {}
    local ret = 'FAIL'
    local cmd
    --local ssid
    --local wpapsk
    
    if arg ~= nil then
    
        file = io.open ("/tmp/wlanbridgeTest.arg", "w")
        file:write(arg["ifname"]..'\n')
        file:write(arg["ssid"]..'\n')
        file:write(arg["auth"]..'\n')
        file:write(arg["enc"]..'\n')
        file:write(arg["wpapsk"]..'\n')
        io.close(file)
        cmd = '/bin/wlanbridge_test.sh '
        --ssid = arg["ssid"]
        --wpapsk = arg["wpapsk"]     
    
        --cmd = '/bin/wlanbridge_test.sh '..arg["ifname"]..' \''..ssid..'\' '..arg["auth"]..' '..arg["enc"]..' \''..wpapsk..'\''
        --print(cmd)
        local w = assert(io.popen(cmd, 'r'))
        local str = assert(w:read('*a'))
        w:close()

        if string.match(str, "PASS") then
            ret = 'PASS'
        else
            ret = 'FAIL'
        end
    end
    
    jrt["ifname"] = arg["ifname"]
    jrt["result"] = ret
    return json.encode(jrt)

end

function runtime.easyMesh(arg)
	local ret = '"NOK"'
	local jrt = {}
	local f, w, str

	os.execute("/usr/bin/meshtopo")

	local file = io.open("/tmp/mesh.txt", "r")
	if file then
		f = file:read("*all")
		file:close()
	end

	local r, k = pcall(json.decode, f)
	if r then
		topo = k
	else
		topo = {}
	end

	jrt["easyMesh"] = topo

	ret = json.encode(jrt)
	return ret
end

function runtime.easyMeshWps(arg)
	local ret = '"NOK"'

	if arg ~= nil then
		local cmd

		if arg["action"] == 'wps' then
			cmd = '/usr/bin/easymesh_main.sh wps'
			os.execute(cmd)
		elseif arg["action"] == 'cancel' then
			cmd = '/usr/bin/easymesh_main.sh wps_cancel'
			os.execute(cmd)
		else
			print("Unknown action!!!")
		end

		ret = '"OK"'
		return ret
	else
		local f, w, str, cmd
		local jrt = {}

		cmd = '/usr/bin/easymesh_main.sh wps_status'
		w = assert(io.popen(cmd))
		str = assert(w:read('*a'))
		local wps_status = string.gsub(str, "\n", "")
		w:close()

		jrt["wps_status"] = wps_status

		ret = json.encode(jrt)
		return ret
	end

	return ret
end

function runtime.easyMeshMsg(arg)
	-- easyMesh & easyMeshMsg conflict key: Name, IP
	-- will use easyMeshMsg to overwrite
	local ret = '"NOK"'
	local jrt = {}
	local f, w, str

	--os.execute("killall -SIGUSR1 mapd_iface")

	local file = io.open("/tmp/mesh_msg.txt", "r")
	if file then
		f = file:read("*all")
		file:close()
	else
		f = "{\"Devices\":[]}"
	end

	local r, k = pcall(json.decode, f)
	if r then
		msg = k
	else
		msg = {}
	end

	file = io.open("/tmp/gdata/agent_names", "r")
	if file then
		for line in file:lines() do
			local mac, name = line:match("(%S+) (.+)")

			for i, dev in ipairs(msg["Devices"]) do
				if string.match(dev["ALMAC"], mac) then
					dev["Name"] = name
				end
			end
		end
		file:close()
	end

	jrt["easyMeshMsg"] = msg

	ret = json.encode(jrt)
	return ret
end

function runtime.easyMeshSetName(arg)
	local ret = '"NOK"'
	local mac

	if arg ~= nil then
		local file = assert(io.open("/tmp/new_agent", "r"))
		if file then
			mac = file:read("*all")
			file:close()
		end

		local name_file = "/tmp/gdata/agent_names"

		local cmd = "sed -i " .. "\'/" .. mac .. "/d\' " .. name_file
		os.execute(cmd)

		file = assert(io.open(name_file, "a"))
		file:write(mac .. " " .. arg["name"] .. "\n")
		file:close()

		ret = '"OK"'
	else
		ret = '"NOK"'
	end

	return ret
end

function runtime.easyMeshNewAgent(arg)
	local ret = '"NOK"'
	local f, w, file
	local r, k
	local old_topo, new_topo

	if arg ~= nil then
		if arg["action"] == 'save' then
			file = assert(io.open("/tmp/mesh_old", "r"))
			if file then
				f = file:read("*all")
				file:close()
			end

			r, k = pcall(json.decode, f)
			if r then
				old_topo = k
			else
				old_topo = {}
			end

			os.execute("/usr/bin/meshtopo")
			file = assert(io.open("/tmp/mesh.txt", "r"))
			if file then
				f = file:read("*all")
				file:close()
			end

			r, k = pcall(json.decode, f)
			if r then
				new_topo = k
			else
				new_topo = {}
			end

			os.remove("/tmp/new_agent")

			local found = 0

			for i, dev in ipairs(new_topo["Devices"]) do
				found = 0

				for j, record in ipairs(old_topo["Devices"]) do

					if string.match(dev["ALMAC"], record["ALMAC"]) then
						found = 1
						break
					end

				end

				if found ~= 1 then
					file = assert(io.open("/tmp/new_agent", "w"))
					file:write(dev["ALMAC"])
					file:close()
					return '"OK"'
				end
			end
		end
	end

	ret = '"OK"'

	return ret
end

return runtime
