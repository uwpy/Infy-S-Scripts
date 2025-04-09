--!optimize 2

-- Base64 decoder function
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

-- Function to read bytecode from the decoded string
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

local function IsInvalid(str)
	return str:find(" ") or str:find("%d") or str:find("[-+|/]") ~= nil
end

local function GetParams(func)
	local Info, Vals = debug.getinfo(func), {}
	for ind = 1, Info.nparams do
		table.insert(Vals, "Val" .. tostring(ind))
	end
	if Info.is_vararg then
		table.insert(Vals, "...")
	end
	return table.concat(Vals, ", ")
end

local function GetColorRGB(Color)
	local R, G, B
	local split = tostring(Color):gsub(" ", ""):split(",")
	R = math.floor(tonumber(split[1]) * 255)
	G = math.floor(tonumber(split[2]) * 255)
	B = math.floor(tonumber(split[3]) * 255)
	return (tostring(R) .. ", " .. tostring(G) .. ", " .. tostring(B))
end

local function GetIndex(Index)
	if tostring(Index):len() < 1 then
		return "[\"" .. tostring(Index) .. "\"]"
	elseif tonumber(Index) then
		return "[" .. tostring(Index) .. "]"
	elseif IsInvalid(tostring(Index)) then
		return "[\"" .. tostring(Index) .. "\"]"
	else
		return tostring(Index)
	end
end

-- Function to decompile the bytecode
local function Decompile(bytecode)
	local decodedBytecode = decodeBase64(bytecode)
	local instructions = readBytecode(decodedBytecode)
	local outputLines = {}
	local variableCount = 0
	local usedServices = {}

	local function allocateVariable(prefix)
		variableCount = variableCount + 1
		return prefix .. variableCount
	end

	local services = {
		RunService = "game:GetService('RunService')",
		Players = "game:GetService('Players')",
		PolicyService = "game:GetService('PolicyService')",
		UserInputService = "game:GetService('UserInputService')",
		Lighting = "game:GetService('Lighting')",
		ReplicatedStorage = "game:GetService('ReplicatedStorage')",
		ServerStorage = "game:GetService('ServerStorage')",
		ServerScriptService = "game:GetService('ServerScriptService')",
		StarterGui = "game:GetService('StarterGui')",
		StarterPack = "game:GetService('StarterPack')",
		StarterPlayer = "game:GetService('StarterPlayer')",
		SoundService = "game:GetService('SoundService')",
		Teams = "game:GetService('Teams')",
		Debris = "game:GetService('Debris')",
		HttpService = "game:GetService('HttpService')",
		DataStoreService = "game:GetService('DataStoreService')",
		MarketplaceService = "game:GetService('MarketplaceService')",
		PhysicsService = "game:GetService('PhysicsService')",
		PathfindingService = "game:GetService('PathfindingService')",
		BadgeService = "game:GetService('BadgeService')",
		InsertService = "game:GetService('InsertService')",
		GroupService = "game:GetService('GroupService')",
		AssetService = "game:GetService('AssetService')",
		TextService = "game:GetService('TextService')",
		VRService = "game:GetService('VRService')",
		HapticService = "game:GetService('HapticService')",
		ContextActionService = "game:GetService('ContextActionService')",
		ProximityPromptService = "game:GetService('ProximityPromptService')",
		CollectionService = "game:GetService('CollectionService')",
		KeyframeSequenceProvider = "game:GetService('KeyframeSequenceProvider')",
		LocalizationService = "game:GetService('LocalizationService')",
		NetworkClient = "game:GetService('NetworkClient')",
		NetworkServer = "game:GetService('NetworkServer')",
		AdService = "game:GetService('AdService')",
		Chat = "game:GetService('Chat')",
		TweenService = "game:GetService('TweenService')",
		Selection = "game:GetService('Selection')",
		AnimationService = "game:GetService('AnimationService')",
		NotificationService = "game:GetService('NotificationService')",
		AnalyticsService = "game:GetService('AnalyticsService')"
	}

	for _, instruction in ipairs(instructions) do
		local opcode, a, b, c = instruction.opcode, instruction.a, instruction.b, instruction.c

		if opcode == 0x07 then  -- OP_GLOBAL
			local tempVar = allocateVariable("globalVar")
			outputLines[#outputLines + 1] = string.format("local %s = _ENV[%q];", tempVar, a)
		elseif opcode == 0x08 then  -- OP_SETGLOBAL
			local tempVar = "v" .. b
			outputLines[#outputLines + 1] = string.format("_ENV[%q] = %s;", a, tempVar)
		elseif opcode == 0x02 then  -- OP_LOADK
			local constVar = allocateVariable("const")
			outputLines[#outputLines + 1] = string.format("local %s = %s;", constVar, a)
		elseif opcode == 0x05 then  -- OP_CALL
			local funcVar = "v" .. (b - 1)
			local args = {}
			for i = 1, c do
				table.insert(args, "v" .. (b + i - 1))
			end
			outputLines[#outputLines + 1] = string.format("%s(%s);", funcVar, table.concat(args, ", "))
		elseif opcode == 0x09 then  -- OP_RETURN
			local returns = {}
			for i = 1, a do
				table.insert(returns, "v" .. i)
			end
			outputLines[#outputLines + 1] = string.format("return %s;", table.concat(returns, ", "))

		elseif opcode == 0x0A then  -- OP_JUMP
			outputLines[#outputLines + 1] = string.format("goto label_%d;", c)

		elseif opcode == 0x0B then  -- OP_LABEL
			outputLines[#outputLines + 1] = string.format("label_%d:", c)

		elseif opcode == 0x0C then  -- OP_NOOP (no operation)
			outputLines[#outputLines + 1] = "-- No operation"

		elseif opcode == 0x0D then  -- OP_SETLOCAL
			outputLines[#outputLines + 1] = string.format("local v%d = %s;", b, "v" .. c)

		elseif opcode == 0x0E then  -- OP_SELF
			local selfVar = allocateVariable("self")
			outputLines[#outputLines + 1] = string.format("local %s = v%d;", selfVar, a)

		elseif opcode == 0x0F then  -- OP_ADD
			outputLines[#outputLines + 1] = string.format("v%d = v%d + v%d;", a, b, c)

		elseif opcode == 0x10 then  -- OP_SUBTRACT
			outputLines[#outputLines + 1] = string.format("v%d = v%d - v%d;", a, b, c)

		elseif opcode == 0x11 then  -- OP_MULTIPLY
			outputLines[#outputLines + 1] = string.format("v%d = v%d * v%d;", a, b, c)

		elseif opcode == 0x12 then  -- OP_DIVIDE
			outputLines[#outputLines + 1] = string.format("v%d = v%d / v%d;", a, b, c)

		elseif opcode == 0x13 then  -- OP_CONCAT (concatenation)
			outputLines[#outputLines + 1] = string.format("v%d = v%d .. v%d;", a, b, c)

		elseif opcode == 0x14 then  -- OP_UNM (unary minus)
			outputLines[#outputLines + 1] = string.format("v%d = -v%d;", a, b)

		elseif opcode == 0x15 then  -- OP_NOT (logical NOT)
			outputLines[#outputLines + 1] = string.format("v%d = not v%d;", a, b)

		elseif opcode == 0x16 then  -- OP_EQ (equality check)
			outputLines[#outputLines + 1] = string.format("if v%d == v%d then goto label_%d;", a, b, c)

		elseif opcode == 0x17 then  -- OP_NE (inequality check)
			outputLines[#outputLines + 1] = string.format("if v%d ~= v%d then goto label_%d;", a, b, c)
		end

		if services[a] then
			usedServices[a] = true
		end
	end

	local decomMark = "-- Decompiled using Scorpion luau decompiler.\n\n"
	local serviceLines = {}
	for key in pairs(usedServices) do
		table.insert(serviceLines, string.format("local %s = %s;", key, services[key]))
	end

	return decomMark .. table.concat(serviceLines, "\n") .. "\n" .. table.concat(outputLines, "\n")
end

local _ENV = (getgenv or getrenv or getfenv)()
_ENV.decompile = function(script)
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

	return Decompile(result) .. "\n"
end
