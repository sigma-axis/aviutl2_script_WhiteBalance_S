--information:色温度σ@WhiteBalance_S ${PACKAGE_VERSION} by ${AUTHOR}
--label:WhiteBalance_S
--filter
--require:${LEAST_AVIUTL_VERSION}
---$track:変換元K, min = 1666.67, max = 25000, step = 0.01, scale = 0.4
local temp_base = 6500

---$track:変換先K, min = 1666.67, max = 25000, step = 0.01, scale = 0.4
local temp_dest = 6500

---$track:変換元M, min = 40, max = 600, step = 0.001
local mired_base = 154

---$track:変換先M, min = 40, max = 600, step = 0.001
local mired_dest = 154

---$nolang: options
---$select:単位
---K = 0
---Mired = 1
local unit = 0

--hide@temp_base:unit~=0
--hide@temp_dest:unit~=0
--hide@mired_base:unit==0
--hide@mired_dest:unit==0
---$nolang: options
---$select:色空間
---XYZ = 0
---RGB = 1
local space = 0

--group:その他,false
---$nolang: name
---$tips:PI = {
---     :  temp_base: number?,
---     :  temp_dest: number?,
---     :  mired_base: number?,
---     :  mired_dest: number?,
---     :  unit: string?
---     :  space: string?,
---     :}
---$value:PI
local PI = {}

local obj, math, tonumber = obj, math, tonumber;

--#region PI / normalize parameters.

-- take parameters.
temp_base = tonumber(PI.temp_base) or temp_base;
temp_dest = tonumber(PI.temp_dest) or temp_dest;
mired_base = tonumber(PI.mired_base) or mired_base;
mired_dest = tonumber(PI.mired_dest) or mired_dest;
if type(PI.unit) == "string" then
	local name2num = { ["K"] = 0, ["Mired"] = 1 };
	unit = name2num[PI.unit] or unit;
end
local space_name;
if type(PI.space) == "string" then space_name = PI.space;
else
	local num2name = { "XYZ", "RGB" };
	space_name = num2name[space + 1] or "XYZ";
end

-- normalize parameters.
if unit == 1 then
	mired_base = math.min(math.max(mired_base, 40), 600);
	mired_dest = math.min(math.max(mired_dest, 40), 600);
	temp_base, temp_dest = 10 ^ 6 / mired_base, 10 ^ 6 / mired_dest;
end
temp_base = math.min(math.max(temp_base, 1666.67), 25000);
temp_dest = math.min(math.max(temp_dest, 1666.67), 25000);
if temp_base == temp_dest then return end

--#endregion PI / normalize parameters.

-- further calculations.
local function calc_xz(T)
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
local x1, z1 = calc_xz(temp_base);
local x2, z2 = calc_xz(temp_dest);
local y1, y2 = 1, 1;
if space == "RGB" then
	local m1_i = {
		 3.2406254773201,   -1.5372079722103, -0.49862859869825;
		-0.96893071472932,   1.8757560608852,  0.041517523842954;
		 0.055710120445511, -0.20402105059849, 1.0569959422544;
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

-- apply effect.
obj.effect("ホワイトバランスσ@WhiteBalance_S", "PI", ("space=%q,col_dest={%s,%s,%s}"):format(
	space_name, 100 * x2 / x1, 100 * y2 / y1, 100 * z2 / z1));
