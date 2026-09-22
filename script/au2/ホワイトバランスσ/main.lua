--information:ホワイトバランスσ@WhiteBalance_S ${PACKAGE_VERSION} by ${AUTHOR}
--label:WhiteBalance_S
--filter
--require:${LEAST_AVIUTL_VERSION}
---$track:強さ, min = 0, max = 100, step = 0.01
local rate = 100

---$checksection:成分を個別に指定
local col_indiv = false

---$color:変換元
local col_base = 0xffffff

--hide@col_base:col_indiv==1
---$color:変換先
local col_dest = 0xffffff

--hide@col_dest:col_indiv==1
---$checksection:正規化
local normalize = true

--hide@normalize:col_indiv==1
---$track:倍率X/R, min = 0, max = 200, step = 0.01
local comp1 = 100

--hide@comp1:col_indiv==0
---$track:倍率Y/G, min = 0, max = 200, step = 0.01
local comp2 = 100

--hide@comp2:col_indiv==0
---$track:倍率Z/B, min = 0, max = 200, step = 0.01
local comp3 = 100

--hide@comp3:col_indiv==0
--group
---$nolang: options
---$select:色空間
---XYZ = 0
---RGB = 1
local space = 0

--group:その他,false
---$nolang: name
---$tips:PI = {
---     :  rate: number?,
---     :  col_base: number?,
---     :  col_dest: number|table|nil,
---     :  normalize: boolean|number|nil,
---     :  space: string?,
---     :}
---$value:PI
local PI = {}

--[[pixelshader@by_rgb:
---$include "by_rgb.hlsl"
]]
--[[pixelshader@by_xyz:
---$include "by_xyz.hlsl"
]]
local obj, math, bit_band, tonumber, type = obj, math, bit.band, tonumber, type;

--#region PI / normalize parameters.

-- take parameters.
local function as_bool(t, v)
	if type(t) == "boolean" then return t;
	elseif type(t) == "number" then return t ~= 0;
	else return v end
end
rate = tonumber(PI.rate) or rate;
col_base = tonumber(PI.col_base) or col_base;
if type(PI.col_dest) == "table" then
	comp1, comp2, comp3, col_indiv =
		tonumber(PI.col_dest[1]) or comp1,
		tonumber(PI.col_dest[2]) or comp2,
		tonumber(PI.col_dest[3]) or comp3,
		true;
else
	local c = tonumber(PI.col_dest);
	if c then col_dest, col_indiv = c, false end
end
normalize = as_bool(PI.normalize, normalize);
if type(PI.space) == "string" then
	local name2num = {
		["XYZ"] = 0, ["RGB"] = 1,
	};
	space = name2num[PI.space] or space;
end

-- normalize parameters.
rate = math.min(math.max(rate / 100, 0), 1); if rate <= 0 then return end
col_base = math.floor(0.5 + col_base) % 2 ^ 24;
col_dest = math.floor(0.5 + col_dest) % 2 ^ 24;
comp1, comp2, comp3 =
	math.max(comp1 / 100, 0), math.max(comp2 / 100, 0), math.max(comp3 / 100, 0);
space = math.min(math.max(math.floor(0.5 + space), 0), 1);

--#endregion PI / normalize parameters.

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
	if space == 0 then -- XYZ
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
		if space ~= 0 then
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
	obj.pixelshader(space == 0 and "by_xyz" or "by_rgb", "object", "object", {
		comp1, comp2, comp3,
	});
end
