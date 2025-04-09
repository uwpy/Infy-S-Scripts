local Reader = {}

function Reader.base64Decode(input)
	-- Debugging: Show the raw input
	print("Input to decode: " .. (input or "nil"))

	-- Remove whitespace from input
	input = input:gsub('%s+', '')

	-- Base64 character set
	local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='

	-- Clean invalid characters from input
	input = input:gsub('[^' .. b .. ']', '')
	print("Cleaned input: " .. input)

	-- Decoding process
	local result = (input:gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', (b:find(x) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
		end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		return string.char(tonumber(x, 2))
	end))

	-- Final debug output
	print("Decoded result: " .. (result and string.format("'%s'" , result) or "nil"))

	return result
end

function Reader.readNextByte(bytecode)
	if not bytecode then
		warn("Error: bytecode is nil")
		return {}
	end

	local position = 1
	local function readByte()
		if position > #bytecode then return nil end -- Prevent reading beyond the string
		local byte = bytecode:byte(position)
		position = position + 1
		return byte
	end

	local instructions = {}
	while position <= #bytecode do
		local opcode = readByte()
		if not opcode then break end  -- Exit if there is no more byte to read
		local a = readByte()
		local b = readByte()
		local c = readByte()

		-- Check if we have all bytes before inserting
		if opcode and a and b and c then
			table.insert(instructions, {opcode, a, b, c})
		else
			warn("Warning: Incomplete instruction read; stopping.")
			break;
		end
	end

	return instructions
end

return Reader
