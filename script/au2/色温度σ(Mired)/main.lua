--information:色温度σ(Mired)@WhiteBalance_S ${PACKAGE_VERSION} by ${AUTHOR}
--label:WhiteBalance_S
--filter
--require:${LEAST_AVIUTL_VERSION}
---$track:変換元M, min = 40, max = 600, step = 0.001
local mired_base = 154

---$track:変換先M, min = 40, max = 600, step = 0.001
local mired_dest = 154

---$nolang: options
---$select:色空間
---XYZ = 0
---RGB = 1
local space = 0

--group:その他,false
---$nolang: name
---$tips:PI = {
---     :  mired_base: number?,
---     :  mired_dest: number?,
---     :  space: string?,
---     :}
---$value:PI
local PI = {}

local obj, math, tonumber = obj, math, tonumber;

--#region PI / normalize parameters.

-- take parameters.
mired_base = tonumber(PI.mired_base) or mired_base;
mired_dest = tonumber(PI.mired_dest) or mired_dest;
local space_name;
if type(PI.space) == "string" then space_name = PI.space;
else
	local num2name = { "XYZ", "RGB" };
	space_name = num2name[space + 1] or "XYZ";
end

-- normalize parameters.
mired_base = math.min(math.max(mired_base, 40), 600);
mired_dest = math.min(math.max(mired_dest, 40), 600);
if mired_base == mired_dest then return end

--#endregion PI / normalize parameters.

-- apply effect.
obj.effect("色温度σ@WhiteBalance_S", "PI", ("space=%q,temp_base=%s,temp_dest=%s"):format(
	space_name, 10 ^ 6 / mired_base, 10 ^ 6 / mired_dest));
