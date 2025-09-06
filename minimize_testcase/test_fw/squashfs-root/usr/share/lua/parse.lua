-- parse.lua
local obj = require('libobj')
local json = require('json')
local parse = {}

SETDBG = 1
function printd(x)
	if SETDBG == 1 then 
		print(x)
	end
end

function parse.obj_list(str)
	local rt = {}
	if str ~= nil and string.len(str) ~= 0  then
		local cstr = string.gsub(str, "&_=.*", '')
		printd('req: '..cstr)
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

        for i,t in pairs(rt) do
		printd(i .. '=' .. t)
	end

	return rt
end

function parse.check_item(str)
	local itemstr = ''
	if str ~= nil and string.len(str) ~= 0  then
		local rt = {}
		string.gsub(str, '[^%p*]+', function(w) table.insert(rt, w) end )

		for i,t in ipairs(rt) do
			if t == 'obj' then
				itemstr = t
				break
			elseif t == 'info' then
				itemstr = t
				break
			else
				printd('item='..t)
			end
		end
	else
		printd('Not string!!!')
	end

	return itemstr
end

function parse.merge_objname(oristr, name)
	local objson = obj.json_get(name)
	local modjson = '{}'
	if objson == nil then
		modjson = '{'..'"'..name..'"'..': "NOK"}'
	else
		modjson = '{'..'"'..name..'"'..':'..objson..'}'
	end

        local retstr = oristr
        if string.len(retstr) == 0 then
                retstr = modjson
        else
                local tmpori = string.gsub (string.reverse(oristr), '}', ',', 1)
                local tmpadd = string.reverse(string.gsub (modjson, '{', '', 1))
                retstr = string.reverse(tmpadd..tmpori)
        end

        return retstr
end

function parse.obj_split(str)
	rt = {}
	if str ~= nil then
		for s in string.gmatch(str, '"+%w+":{') do
			string.gsub(s, '[^%p*]+', function(w) table.insert(rt, w) end )
		end
	else
		print('[Error] Get nil string!!!')
	end

        for i,t in pairs(rt) do
		printd(i .. '=' .. t)
	end

	return rt
end

function parse.merge_objlist(str)
	local tab = {}
	tab = parse.obj_list(str)

	local mstr = ''
	if type(tab) == "table" then
		for i,t in ipairs(tab) do
			printd('merge obj '.. t)
			mstr = parse.merge_objname(mstr, t)
		end
		--mstr = string.gsub(mstr, '%s', '')
	end

	return mstr
end


function parse.set_objlist(str)
	local itab = {}
	local r, gettab = pcall(json.decode, str)
	if r then
		for k,v in pairs(gettab) do
			if type(v) == "table" then
				table.insert(itab, k)
			end
		end

		--PrintTable(gettab)
		for i,t in ipairs(itab) do
			local objson = json.encode(gettab[t])
			if string.len(objson) <= 2 then
				printd('obj '..t..' is empty')
				gettab[t] = json.decode(obj.json_get(t))
			else
				if string.match(objson, '"+%w+T+":%[') ~= nil then
					printd('Get '..t..' is a table, remove and than set')
					obj.reset(t)
				end 
				if obj.json_set(t, objson) then
					printd('Set obj '..t..' done')
					gettab[t]="OK"
					os.execute("/usr/bin/rcConf obj "..t)
					os.execute("/usr/bin/objsync "..t)
				else
					printd('Set obj '..t..' fail!!!')
					gettab[t] = "Fail"
				end
			end
		end
		--PrintTable(gettab)
		os.execute("/usr/bin/gnvram commit")
		os.execute("/usr/bin/rcConf run")
	else
		printd('Json format error!!!')
		gettab = { jsonString = 'Fail' }
	end

	return json.encode(gettab)
end

local key = ""
function PrintTable(table , level)
	level = level or 1
	local indent = ""
	for i = 1, level do
		indent = indent.."  "
	end

	if key ~= "" then
		print(indent..key.." ".."=".." ".."{")
	else
		print(indent .. "{")
	end

	key = ""
	for k,v in pairs(table) do
		if type(v) == "table" then
			key = k
			PrintTable(v, level + 1)
		else
			local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
			print(content)  
		end
	end
	print(indent .. "}")
end

return parse
