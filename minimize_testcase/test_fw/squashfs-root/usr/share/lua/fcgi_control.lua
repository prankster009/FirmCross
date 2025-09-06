#!/usr/bin/env lua
local fcgi = require( "fcgi" )
local parse = require('parse')
local runtime = require('runtime')

-- Accept requests in a loop
RUNPATH=io.popen("pwd"):read()
print("Path="..RUNPATH)

local bufferlen = 4096

print('Starting')
while fcgi.accept() == 0 do
	--Show env code
	--[[local envtable = fcgi.getEnv()
	PrintTable(envtable) ]]

	local action = fcgi.getParam('REQUEST_METHOD')
	--local getpath = fcgi.getParam('PATH_INFO')
	local item = parse.check_item(fcgi.getParam('PATH_INFO'))
	print('[action,item] =  ['..action..','..item..']')
	local retstr = ''

	local server_name = fcgi.getParam('SERVER_NAME')
	local http_origin = fcgi.getParam('HTTP_ORIGIN')
	local http_referer = fcgi.getParam('HTTP_REFERER')
	local http_host = fcgi.getParam('HTTP_HOST')
	local check = nil

	-- check referer field is from same site
	if http_referer ~= nil and http_host ~= nil then
		check = string.find(http_referer, http_host, 1, true)
	end

	-- referer field not found , check origin field is from same site
	if check == nil and (http_origin ~= nil and server_name ~= nil) then
		check = string.find(http_origin, server_name, 1, true)
	end

	if action == 'GET' then
		local getlist = fcgi.getParam('QUERY_STRING')
		--local item = parse.check_item(getpath)
		if getlist ~= nil then
			if item == 'obj' then
				retstr = parse.merge_objlist(getlist)
			elseif item == 'info' then
				retstr = runtime.merge_infolistjson(getlist)
			else
				print('Unknown get item '..item)
			end
		else
			print("[Error] Can't get request list!!!")
		end
	elseif action == 'POST' then
		-- Only POST have HTTP_CONTENT_LENGTH
		local len = fcgi.getParam('HTTP_CONTENT_LENGTH')
		if len == nil or len == 0 then
			print("Can't get any content!!!")
		else
			print('content length= ' .. len)
			local getline = fcgi.getLine(bufferlen)

			if getline ~= nil and check ~= nil then
				if item == 'obj' then
					retstr = parse.set_objlist(getline)
				elseif item == 'info' then
					retstr = runtime.exeparam(getline)
				else
					print('Unknown post item '..item)
				end
			else
				print("[Error] Can't get post obj list!!!")
				fcgi.putStr('Status: 400 Bad Request\n')
				retstr = '{"api_return":400,"error":"Bad Request"}'
			end
		end
	end
	--printd(retstr)

	-- Send some HTML to the client and header for REST test show
	--fcgi.putStr('Access-Control-Allow-Origin: *\n')
	fcgi.putStr('Content-Type: application/json \n\n')
	--[[ It needs \n\n to show all data from stream ]]
	fcgi.putStr(retstr)

	-- finish this request
	fcgi.finish()
end
print('ending')
