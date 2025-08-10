cbuffer UBO: register(b0, space1)
{
    row_major float4x4 mvp: packoffset(c0);
}

struct VertexInput {
    float3 position: TEXCOORD0;
    float4 color: TEXCOORD1;
    float2 uv: TEXCOORD2;
};

struct VertexOutput {
    float4 position: SV_Position;
    float4 color: TEXCOORD0;
    float2 uv: TEXCOORD1;
};

VertexOutput main(VertexInput input)
{
    VertexOutput output;
    output.position = mul(float4(input.position, 1.0f), mvp);
    //output.position = float4(input.position, 1.0f);
    output.color = input.color;
    output.uv = input.uv;
    return output;
}
