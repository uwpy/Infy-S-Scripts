--!optimize 2

local function decodeBase64(input)
	local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	input = input:gsub('[^' .. b .. '=]', '')

	return (input:gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', (b:find(x) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
		end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		return #x == 8 and string.char(tonumber(x, 2)) or ''
	end))
end

local function readBytecode(bytecode)
	local position = 1
	local instructions = {}

	local function readByte()
		if position > #bytecode then return nil end
		local byte = bytecode:byte(position)
		position = position + 1
		return byte
	end

	while true do
		local opcode = readByte()
		if not opcode then break end

		local a, b, c = readByte(), readByte(), readByte()
		if not (a and b and c) then break end

		table.insert(instructions, {opcode = opcode, a = a, b = b, c = c})
	end
	return instructions
end

local function getconstant(bytecode, index)
	-- Luau constant extraction.
	-- This assumes that constants are stored in a table following the bytecode.
	local constant = bytecode.constants[index + 1] -- Luau constants start from index 1
	if constant == nil then
		return "CONSTANT_NOT_FOUND"
	end
	if type(constant) == "string" then
		return "\"" .. constant .. "\""
	elseif type(constant) == "number" then
		return tostring(constant)
	elseif type(constant) == "boolean" then
		return tostring(constant)
	elseif type(constant) == "table" then
		-- Handle table constants.
		local tableStr = "{"
		for k, v in pairs(constant) do
			tableStr = tableStr .. tostring(k) .. " = " .. tostring(v) .. ", "
		end
		tableStr = tableStr:sub(1, -3) .. "}"
		return tableStr
	else
		return "CONSTANT_NOT_FOUND"
	end
end

local function getparam(bytecode, index)
	return "param" .. index
end

local function getArguments(bytecode, instr)
	local opcode = instr.opcode
	local args = {}
	if opcode == 1 then -- OP_LOADK
		args[1] = instr.arg.b
	elseif opcode == 2 then -- OP_LOADBOOL
		args[1] = instr.arg.a
		args[2] = instr.arg.b
	elseif opcode == 3 then -- OP_LOAD NIL
		args[1] = instr.arg.b
		args[2] = instr.arg.c
	elseif opcode == 4 then -- OP_GETUPVAL
		args[1] = instr.arg.b
	elseif opcode == 5 then -- OP_GETGLOBAL
		args[1] = instr.arg.bx
	elseif opcode == 6 then -- OP_GETTABLE
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 7 then -- OP_SETGLOBAL
		args[1] = instr.arg.bx
	elseif opcode == 8 then -- OP_SETUPVAL
		args[1] = instr.arg.b
	elseif opcode == 9 then -- OP_SETTABLE
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 10 then -- OP_NEWTABLE
		args[1] = instr.arg.b
		args[2] = instr.arg.c
	elseif opcode == 11 then -- OP_SELF
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 12 then -- OP_ADD
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 13 then -- OP_SUB
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 14 then -- OP_MUL
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 15 then -- OP_DIV
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 16 then -- OP_MOD
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 17 then -- OP_POW
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 18 then -- OP_UNM
		args[1] = instr.arg.b
	elseif opcode == 19 then -- OP_NOT
		args[1] = instr.arg.b
	elseif opcode == 20 then -- OP_LEN
		args[1] = instr.arg.b
	elseif opcode == 21 then -- OP_CONCAT
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 22 then -- OP_JMP
		args[1] = instr.arg.sb
	elseif opcode == 23 then -- OP_EQ
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 24 then -- OP_LT
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 25 then -- OP_LE
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 26 then -- OP_TEST
		args[1] = instr.arg.a
		args[2] = instr.arg.c
	elseif opcode == 27 then -- OP_TESTSET
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 28 then -- OP_CALL
		args[1] = instr.arg.a
		args[2] = instr.arg.c
	elseif opcode == 29 then -- OP_TAILCALL
		args[1] = instr.arg.a
		args[2] = instr.arg.c
	elseif opcode == 30 then -- OP_RETURN
		args[1] = instr.arg.a
		args[2] = instr.arg.c
	elseif opcode == 31 then -- OP_FORLOOP
		args[1] = instr.arg.a
		args[2] = instr.arg.sb
	elseif opcode == 32 then -- OP_FORPREP
		args[1] = instr.arg.a
		args[2] = instr.arg.sb
	elseif opcode == 33 then -- OP_TFORLOOP
		args[1] = instr.arg.a
		args[2] = instr.arg.c
	elseif opcode == 34 then -- OP_SETLIST
		args[1] = instr.arg.a
		args[2] = instr.arg.b
		args[3] = instr.arg.c
	elseif opcode == 35 then -- OP_CLOSURE
		args[1] = instr.arg.bx
	elseif opcode == 36 then -- OP_VARARG
		args[1] = instr.arg.a
		args[2] = instr.arg.c
	elseif opcode == 37 then -- OP_VARARGPREP
		args[1] = instr.arg.a
		args[2] = instr.arg.b
	elseif opcode == 38 then -- OP_EXTRAARG
		args[1] = instr.arg.ax
	end
	return args
end

local Builtins = {
	["print"] = true,
	["warn"] = true,
	["pairs"] = true,
	["ipairs"] = true,
	["next"] = true,
	["assert"] = true,
	["type"] = true,
	["tostring"] = true,
	["tonumber"] = true,
	["getmetatable"] = true,
	["setmetatable"] = true,
	["rawget"] = true,
	["rawset"] = true,
	["rawequal"] = true,
	["math"] = true,
	["string"] = true,
	["table"] = true,
	["coroutine"] = true,
	["os"] = true,
	["debug"] = true
}


local function formatInstruction(bytecode, instr, instructionIndex)
	local opcode = instr.opcode
	local args = getArguments(bytecode, instr)

	local formattedInstruction = ""

	if opcode == 1 then -- OP_LOADK
		formattedInstruction = "local v" .. args[1] .. " = " .. getconstant(bytecode, args[1])
	elseif opcode == 2 then -- OP_LOADBOOL
		formattedInstruction = "local v" .. args[1] .. " = " .. tostring(args[2] ~= 0)
	elseif opcode == 3 then -- OP_LOAD NIL
		formattedInstruction = "local v" .. args[1] .. " = nil"
	elseif opcode == 4 then -- OP_GETUPVAL
		formattedInstruction = "local v" .. args[1] .. " = upval" .. args[1]
	elseif opcode == 5 then -- OP_GETGLOBAL
		local globalName = getconstant(bytecode, args[1])
		if Builtins[globalName:gsub("\"","")] or globalName == "\"script\"" or globalName == "\"game\"" then -- Special case script
			formattedInstruction = "local v" .. args[1] .. " = " .. globalName:gsub("\"","")
		else
			formattedInstruction = "local v" .. args[1] .. " = " .. globalName
		end
	elseif opcode == 6 then -- OP_GETTABLE
		-- Attempt to detect FindFirstChild calls
		if args[2] >= 0 then -- Check if we are accessing another variable
			local prevInstr = bytecode.code[instructionIndex - 1]
			if prevInstr and prevInstr.opcode == 5 then
				-- Check if the previous instruction was getting a global
				local globalName = getconstant(bytecode, prevInstr.arg.bx)
				if globalName == "\"script\"" then
					local childName = getconstant(bytecode, args[3])
					if childName then
						formattedInstruction = "local v" .. args[1] .. " = script:FindFirstChild(" .. childName .. ")"
					else
						formattedInstruction = "local v" .. args[1] .. " = v" .. args[2] .. "[" .. (args[3] >= 0 and "v" .. args[3] or getconstant(bytecode, args[3])) .. "]"
					end
				elseif Builtins[globalName:gsub("\"","")] then
					local childName = getconstant(bytecode, args[3])
					formattedInstruction = "local v" .. args[1] .. " = " .. globalName:gsub("\"","") .. "[" .. (args[3] >= 0 and "v" .. args[3] or getconstant(bytecode, args[3])) .. "]"
				else
					formattedInstruction = "local v" .. args[1] .. " = v" .. args[2] .. "[" .. (args[3] >= 0 and "v" .. args[3] or getconstant(bytecode, args[3])) .. "]"
				end
			else
				formattedInstruction = "local v" .. args[1] .. " = v" .. args[2] .. "[" .. (args[3] >= 0 and "v" .. args[3] or getconstant(bytecode, args[3])) .. "]"
			end
		else
			formattedInstruction = "local v" .. args[1] .. " = v" .. args[2] .. "[" .. (args[3] >= 0 and "v" .. args[3] or getconstant(bytecode, args[3])) .. "]"
		end

	elseif opcode == 7 then -- OP_SETGLOBAL
		formattedInstruction = getconstant(bytecode, args[1]) .. " = v" .. args[2]
	elseif opcode == 8 then -- OP_SETUPVAL
		formattedInstruction = "upval" .. args[1] .. " = v" .. args[2]
	elseif opcode == 9 then -- OP_SETTABLE
		formattedInstruction = "v" .. args[1] .. "[" .. (args[2] >= 0 and "v" .. args[2] or getconstant(bytecode, args[2])) .. "] = v" .. args[3]
	elseif opcode == 10 then -- OP_NEWTABLE
		formattedInstruction = "local v" .. args[1] .. " = {}"
	elseif opcode == 11 then -- OP_SELF
		formattedInstruction = "local v" .. args[1] .. " = v" .. args[2] .. "[" .. (args[3] >= 0 and "v" .. args[3] or getconstant(bytecode, args[3])) .. "]"
	elseif opcode == 12 then -- OP_ADD
		formattedInstruction = "v" .. args[3] .. " = v" .. args[1] .. " + v" .. args[2]
	elseif opcode == 13 then -- OP_SUB
		formattedInstruction = "v" .. args[3] .. " = v" .. args[1] .. " - v" .. args[2]
	elseif opcode == 14 then -- OP_MUL
		formattedInstruction = "v" .. args[3] .. " = v" .. args[1] .. " * v" .. args[2]
	elseif opcode == 15 then -- OP_DIV
		formattedInstruction = "v" .. args[3] .. " = v" .. args[1] .. " / v" .. args[2]
	elseif opcode == 16 then -- OP_MOD
		formattedInstruction = "v" .. args[3] .. " = v" .. args[1] .. " % v" .. args[2]
	elseif opcode == 17 then -- OP_POW
		formattedInstruction = "v" .. args[3] .. " = v" .. args[1] .. "^ v" .. args[2]
	elseif opcode == 18 then -- OP_UNM
		formattedInstruction = "v" .. args[1] .. " = -v" .. args[2]
	elseif opcode == 19 then -- OP_NOT
		formattedInstruction = "v" .. args[1] .. " = not v" .. args[2]
	elseif opcode == 20 then -- OP_LEN
		formattedInstruction = "v" .. args[1] .. " = #v" .. args[2]
	elseif opcode == 21 then -- OP_CONCAT
		formattedInstruction = "v" .. args[1] .. " = v" .. args[2] .. " .. v" .. args[3]
	elseif opcode == 22 then -- OP_JMP
		formattedInstruction = "goto instruction " .. (instructionIndex + 1 + args[1])
	elseif opcode == 23 then -- OP_EQ
		formattedInstruction = "if v" .. args[1] .. " == v" .. args[2] .. " then v" .. args[3] .. " = 1 else v" .. args[3] .. " = 0 end"
	elseif opcode == 24 then -- OP_LT
		formattedInstruction = "if v" .. args[1] .. " < v" .. args[2] .. " then v" .. args[3] .. " = 1 else v" .. args[3] .. " = 0 end"
	elseif opcode == 25 then -- OP_LE
		formattedInstruction = "if v" .. args[1] .. " <= v" .. args[2] .. " then v" .. args[3] .. " = 1 else v" .. args[3] .. " = 0 end"
	elseif opcode == 26 then -- OP_TEST
		formattedInstruction = "if v" .. args[1] .. " then goto instruction " .. (instructionIndex + 2) .. " else v" .. args[2] .. " = 0 end"
	elseif opcode == 27 then -- OP_TESTSET
		formattedInstruction = "if v" .. args[1] .. " == v" .. args[2] .. " then goto instruction " .. (instructionIndex + 2) .. " else v" .. args[3] .. " = 0 end"
	elseif opcode == 28 then -- OP_CALL
		formattedInstruction = "local v" .. args[1] .. " = v" .. args[2] .. "("
		local call_args = {}
		for j = 1, args[2] - args[1] do
			table.insert(call_args, "v" .. (args[1] + j))
		end
		formattedInstruction = formattedInstruction .. table.concat(call_args, ", ") .. ")"
	elseif opcode == 29 then -- OP_TAILCALL
		formattedInstruction = "return v" .. args[1] .. "("
		local call_args = {}
		for j = 1, args[2] - args[1] do
			table.insert(call_args, "v" .. (args[1] + j))
		end
		formattedInstruction = formattedInstruction .. table.concat(call_args, ", ") .. ")"
	elseif opcode == 30 then -- OP_RETURN
		formattedInstruction = "return"
	elseif opcode == 31 then -- OP_FORLOOP
		formattedInstruction = "for i = v" .. args[1] .. ", v" .. args[1] + 1 .. " do"
	elseif opcode == 32 then -- OP_FORPREP
		formattedInstruction = "for i = v" .. args[1] .. ", v" .. args[1] + 1 .. " do"
	elseif opcode == 33 then -- OP_TFORLOOP
		formattedInstruction = "local v" .. args[1] .. " = v" .. args[2] .. "("
		local call_args = {}
		for j = 1, args[2] - args[1] do
			table.insert(call_args, "v" .. (args[1] + j))
		end
		formattedInstruction = formattedInstruction .. table.concat(call_args, ", ") .. ")"
	elseif opcode == 34 then -- OP_SETLIST
		formattedInstruction = "v" .. args[1] .. "[" .. args[2] .. "] = v" .. args[3]
	elseif opcode == 35 then -- OP_CLOSURE
		formattedInstruction = "local v" .. args[1] .. " = closure(" .. getconstant(bytecode, args[1]) .. ")"
	elseif opcode == 36 then -- OP_VARARG
		formattedInstruction = "local v" .. args[1] .. " = vararg(" .. args[2] .. ")"
	elseif opcode == 37 then -- OP_VARARGPREP
		formattedInstruction = "local v" .. args[1] .. " = vararg(" .. args[2] .. ")"
	elseif opcode == 38 then -- OP_EXTRAARG
		formattedInstruction = "local v" .. args[1] .. " = extraarg(" .. args[1] .. ")"
	end
	return formattedInstruction
end

local function decompile(bytecode)
	local output = ""
	local i = 1

	while i <= #bytecode.code do
		local instr = bytecode.code[i]
		local instruction = formatInstruction(bytecode, instr, i) -- Pass instruction index
		output = output .. string.format("%5d: ", i) .. instruction .. "\n"
		-- Determine next instruction index
		if instr.opcode == 22 then -- OP_JMP
			i = i + 1 + instr.arg.sb
		elseif instr.opcode == 28 or instr.opcode == 29 then -- OP_CALL, OP_TAILCALL
			i = i + 1
		elseif instr.opcode == 31 or instr.opcode == 32 then -- OP_FORLOOP
			i = i + 1
		elseif instr.opcode == 33 then -- OP_TFORLOOP
			i = i + 1
		elseif instr.opcode == 26 or instr.opcode == 27 then
			i = i + 1
		else
			i = i + 1
		end
	end

	return output
end

local _ENV = (getgenv or getrenv or getfenv)()
_ENV.Decompile = function(script)
	if not getscriptbytecode then
		error("decompile is not enabled. (getscriptbytecode is missing)", 2)
		return
	end

	if typeof(script) ~= "Instance" then
		error("invalid argument #1 to 'decompile' (Instance expected)", 2)
		return
	end

	local function isScriptValid()
		return script.ClassName == "LocalScript" or script.ClassName == "ModuleScript"
	end

	if not isScriptValid() then
		error("invalid argument #1 to 'decompile' (Instance<LocalScript, ModuleScript> expected)", 2)
		return
	end

	local success, result = pcall(getscriptbytecode, script)
	if not success or type(result) ~= "string" then
		error(string.format("decompile failed to grab script bytecode: %s", tostring(result)), 2)
		return
	end
	
	if result:match("^[A-Za-z0-9+/]+={0,2}$") then
		result = decodeBase64(result)
	end
	
	return decompile(result)
end
