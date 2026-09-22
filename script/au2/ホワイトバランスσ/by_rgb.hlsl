Texture2D src : register(t0);
cbuffer constant0 : register(b0) {
	float3 rate;
};
float4 by_rgb(float4 pos : SV_Position) : SV_Target
{
	float4 c = src[pos.xy];
	c.rgb *= rate;
	return c;
}
