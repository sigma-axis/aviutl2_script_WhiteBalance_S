--[[
MIT License
Copyright (c) 2026 sigma-axis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

https://mit-license.org/
]]

--
-- VERSION: v1.01-dev
--

--------------------------------

local GLShaderKit = require "GLShaderKit";
local obj, tonumber, math, bit_band = obj, tonumber, math, bit.band;

local function error_mod(message)
	message = "WhiteBalance_S.lua: "..message;
	debug_print(message);
	local function err_mes()
		obj.setfont("MS UI Gothic", 42, 3);
		obj.load("text", message);
		obj.draw();
	end
	return setmetatable({}, { __index = function(...) return err_mes end });
end
if not GLShaderKit.isInitialized() then return error_mod [=[このデバイスでは GLShaderKit が利用できません!]=];
else
	local function lexical_comp(a, b, ...)
		return a == nil and 0 or a < b and -1 or a > b and 1 or lexical_comp(...);
	end
	local version = GLShaderKit.version();
	local v1, v2, v3 = version:match("^(%d+)%.(%d+)%.(%d+)$");
	v1, v2, v3 = tonumber(v1), tonumber(v2), tonumber(v3);
	-- version must be at least v0.4.0.
	if not (v1 and v2 and v3) or lexical_comp(v1, 0, v2, 4, v3, 0) < 0 then
		debug_print([=[現在の GLShaderKit のバージョン: ]=]..version);
		return error_mod [=[この GLShaderKit のバージョンでは動作しません!]=];
	end
end

-- ref: https://github.com/Mr-Ojii/AviUtl-RotBlur_M-Script/blob/main/script/RotBlur_M.lua
local function script_path()
    return debug.getinfo(1).source:match("@?(.*[/\\])");
end
local shader_path = script_path().."WhiteBalance_S.frag";

local function apply_shader(linear, matrix)
	-- prepare shader context.
	GLShaderKit.activate()
	GLShaderKit.setPlaneVertex(1);
	GLShaderKit.setShader(shader_path, false);

	-- send image buffer to gpu.
	local data, W, H = obj.getpixeldata();
	GLShaderKit.setTexture2D(0, data, W, H);

	-- send uniform variables.
	GLShaderKit.setInt("is_linear", linear and 1 or 0);
	GLShaderKit.setMatrix("conv", "3x3", true, matrix);

	-- invoke the shader.
	GLShaderKit.draw("TRIANGLES", data, W, H);

	-- close the shader context.
	GLShaderKit.deactivate();

	-- put back the result.
	obj.putpixeldata(data);
end

local function apply_xyz(scale_x, scale_y, scale_z)
	local m, m_i = {
		0.4124, 0.3576, 0.1805;
		0.2126, 0.7152, 0.0722;
		0.0193, 0.1192, 0.9505;
	}, {
		 3.2406254773201,   -1.5372079722103, -0.49862859869825 ;
		-0.96893071472932,   1.8757560608852,  0.041517523842954;
		 0.055710120445511, -0.20402105059849, 1.0569959422544  ;
	};
	for j = 1, 3 do
		m[j], m[j + 3], m[j + 6] =
			m_i[1] * scale_x * m[j] + m_i[2] * scale_y * m[j + 3] + m_i[3] * scale_z * m[j + 6],
			m_i[4] * scale_x * m[j] + m_i[5] * scale_y * m[j + 3] + m_i[6] * scale_z * m[j + 6],
			m_i[7] * scale_x * m[j] + m_i[8] * scale_y * m[j + 3] + m_i[9] * scale_z * m[j + 6];
	end
	apply_shader(true, m);
end

local function apply_rgb(scale_r, scale_g, scale_b)
	apply_shader(false, {
		scale_r, 0, 0;
		0, scale_g, 0;
		0, 0, scale_b;
	});
end

local function apply_white_balance(rate, comp1, comp2, comp3, col_indiv, col_dest, col_base, normalize, space)
	-- normalize parameters.
	rate = math.min(math.max(rate, 0), 1); if rate <= 0 then return end
	col_base = math.floor(0.5 + col_base) % 2 ^ 24;
	col_dest = math.floor(0.5 + col_dest) % 2 ^ 24;
	comp1, comp2, comp3 =
		math.max(comp1, 0), math.max(comp2, 0), math.max(comp3, 0);

	-- further calculations.
	if not col_indiv then
		if col_base == col_dest then return end
		local c1, c2, c3 =
			bit_band(col_base, 0xff0000) / 0xff0000,
			bit_band(col_base, 0x00ff00) / 0x00ff00,
			bit_band(col_base, 0x0000ff) / 0x0000ff;
		comp1, comp2, comp3 =
			bit_band(col_dest, 0xff0000) / 0xff0000,
			bit_band(col_dest, 0x00ff00) / 0x00ff00,
			bit_band(col_dest, 0x0000ff) / 0x0000ff;

		local t1, t2, t3, t4, m = 0.04045, 12.92, 0.055, 2.4, {
			0.4124, 0.3576, 0.1805;
			0.2126, 0.7152, 0.0722;
			0.0193, 0.1192, 0.9505;
		};
		if not space then -- XYZ
			c1, c2, c3 =
				c1 <= t1 and c1 / t2 or ((c1 + t3) / (1 + t3)) ^ t4,
				c2 <= t1 and c2 / t2 or ((c2 + t3) / (1 + t3)) ^ t4,
				c3 <= t1 and c3 / t2 or ((c3 + t3) / (1 + t3)) ^ t4;
			c1, c2, c3 =
				m[1] * c1 + m[2] * c2 + m[3] * c3,
				m[4] * c1 + m[5] * c2 + m[6] * c3,
				m[7] * c1 + m[8] * c2 + m[9] * c3;
			comp1, comp2, comp3 =
				comp1 <= t1 and comp1 / t2 or ((comp1 + t3) / (1 + t3)) ^ t4,
				comp2 <= t1 and comp2 / t2 or ((comp2 + t3) / (1 + t3)) ^ t4,
				comp3 <= t1 and comp3 / t2 or ((comp3 + t3) / (1 + t3)) ^ t4;
			comp1, comp2, comp3 =
				m[1] * comp1 + m[2] * comp2 + m[3] * comp3,
				m[4] * comp1 + m[5] * comp2 + m[6] * comp3,
				m[7] * comp1 + m[8] * comp2 + m[9] * comp3;
		end
		comp1, comp2, comp3 =
			comp1 / math.max(c1, 0.0001),
			comp2 / math.max(c2, 0.0001),
			comp3 / math.max(c3, 0.0001);

		if normalize then
			-- normalize so Y of gray pixels remain unchanged.
			local Y = comp2;
			if space then
				local x, y, z =
					comp1 <= t1 and comp1 / t2 or ((comp1 + t3) / (1 + t3)) ^ t4,
					comp2 <= t1 and comp2 / t2 or ((comp2 + t3) / (1 + t3)) ^ t4,
					comp3 <= t1 and comp3 / t2 or ((comp3 + t3) / (1 + t3)) ^ t4;
				Y = m[4] * x + m[5] * y + m[6] * z;
				Y = Y <= 0.0031308 and t2 * Y or (1 + t3) * Y ^ (1 / t4) - t3;
			end
			if Y > 0 then
				comp1, comp2, comp3 =
					comp1 / Y, comp2 / Y, comp3 / Y;
			end
		end
	end

	comp1, comp2, comp3 =
		comp1 ^ rate, comp2 ^ rate, comp3 ^ rate;

	-- apply shader.
	if comp1 ~= 1 or comp2 ~= 1 or comp3 ~= 1 then
		(space and apply_rgb or apply_xyz)(comp1, comp2, comp3);
	end
end

local function calc_temp_xz(T)
	-- cf: https://en.wikipedia.org/wiki/Planckian_locus#Approximation
	local t = 1000 / T;
	local x = T <= 4000 and
		-0.2661239 * t ^ 3 - 0.2343589 * t ^ 2 + 0.8776956 * t + 0.179910 or
		-3.0258469 * t ^ 3 + 2.1070379 * t ^ 2 + 0.2226347 * t + 0.240390
	local y = T <= 2222 and
		-1.1063814 * x ^ 3 - 1.34811020 * x ^ 2 + 2.18555832 * x - 0.20219683 or T <= 4000 and
		-0.9549476 * x ^ 3 - 1.37418593 * x ^ 2 + 2.09137015 * x - 0.16748867 or
		 3.0817580 * x ^ 3 - 5.87338670 * x ^ 2 + 3.75112997 * x - 0.37001483;
	return x / y, (1 - x) / y - 1;
end

local function apply_temperature(temp_base, temp_dest, space)
	-- normalize parameters.
	temp_base = math.min(math.max(temp_base, 1666.67), 25000);
	temp_dest = math.min(math.max(temp_dest, 1666.67), 25000);
	if temp_base == temp_dest then return end

	-- further calculations.
	local x1, z1 = calc_temp_xz(temp_base);
	local x2, z2 = calc_temp_xz(temp_dest);
	local y1, y2 = 1, 1;

	if space then -- RGB
		local m1_i = {
			 3.2406254773201,   -1.5372079722103, -0.49862859869825 ;
			-0.96893071472932,   1.8757560608852,  0.041517523842954;
			 0.055710120445511, -0.20402105059849, 1.0569959422544  ;
		};
		x1, y1, z1 =
			m1_i[1] * x1 + m1_i[2] + m1_i[3] * z1,
			m1_i[4] * x1 + m1_i[5] + m1_i[6] * z1,
			m1_i[7] * x1 + m1_i[8] + m1_i[9] * z1;
		x2, y2, z2 =
			m1_i[1] * x2 + m1_i[2] + m1_i[3] * z2,
			m1_i[4] * x2 + m1_i[5] + m1_i[6] * z2,
			m1_i[7] * x2 + m1_i[8] + m1_i[9] * z2;
	end

	-- apply shader.
	(space and apply_rgb or apply_xyz)(x2 / x1, y2 / y1, z2 / z1);
end

return {
	apply_white_balance = apply_white_balance,
	apply_temperature = apply_temperature,
};
