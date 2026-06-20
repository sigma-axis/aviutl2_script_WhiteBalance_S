/*
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
*/

//
// VERSION: v1.01-dev
//

////////////////////////////////
#version 460 core

in vec2 TexCoord;

layout(location = 0) out vec4 FragColor;

layout(binding = 0) uniform sampler2D texture0;
uniform int is_linear;
uniform mat3 conv;

vec3 to_lin(vec3 c)
{
	vec4 K = { 0.055, 1 / 1.055, 1 / 12.92, 0.04045 };
	return mix(K.z * c, sign(c) * pow((abs(c) + K.x) * K.y, vec3(2.4)), greaterThan(abs(c), K.www));
}
vec3 from_lin(vec3 c)
{
	vec4 K = { 0.055, 1.055, 12.92, 0.0031308 };
	return mix(K.z * c, sign(c) * (K.y * pow(abs(c), 1 / vec3(2.4)) - K.x), greaterThan(abs(c), K.www));
}

void main()
{
	vec4 col = texture(texture0, TexCoord);
	col.rgb = mix(col.rgb, to_lin(col.rgb), is_linear != 0);
	col.rgb = conv * col.rgb;
	col.rgb = mix(col.rgb, from_lin(col.rgb), is_linear != 0);
	FragColor = vec4(clamp(col.rgb, 0, 1), col.a);
}
