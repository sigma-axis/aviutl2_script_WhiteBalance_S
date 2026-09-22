Texture2D src : register(t0);
cbuffer constant0 : register(b0) {
	float3 rate;
};
static const float3x3 m1 = {
	0.4124, 0.3576, 0.1805,
	0.2126, 0.7152, 0.0722,
	0.0193, 0.1192, 0.9505,
}, m1_i = {
	 3.2406254,   -1.537208,  -0.4986286,
	-0.9689307,    1.875756,   0.041517522,
	 0.055710122, -0.20402105, 1.056996,
};
float3 to_xyz(float3 c)
{
	static const float4 K = { 0.055, 1 / 1.055, 1 / 12.92, 0.04045 };
	c = abs(c) <= K.w ? K.z * c : sign(c) * pow((abs(c) + K.x) * K.y, 2.4);
	return mul(m1, c);
}
float3 from_xyz(float3 c)
{
	c = mul(m1_i, c);
	static const float4 K = { 0.055, 1.055, 12.92, 0.0031308 };
	return abs(c) <= K.w ? K.z * c : sign(c) * (K.y * pow(abs(c), 1 / 2.4) - K.x);
}
float4 by_xyz(float4 pos : SV_Position) : SV_Target
{
	float4 c = src[pos.xy];
	c.rgb = c.a > 0 ? c.rgb / c.a : 1;
	c.xyz = to_xyz(c.rgb);
	c.xyz *= rate;
	c.rgb = from_xyz(c.xyz);
	c.rgb *= c.a;
	return c;
}
