Texture2D<float4> tex : register(t0, space2);
SamplerState _tex_sampler : register(s0, space2);

static float4 frag_color;
static float2 uv;
static float4 color;

struct SPIRV_Cross_Input
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
};

struct SPIRV_Cross_Output
{
    float4 frag_color : SV_Target0;
};

void main_inner()
{
    frag_color = tex.Sample(_tex_sampler, uv) * color;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    uv = stage_input.uv;
    color = stage_input.color;
    main_inner();
    SPIRV_Cross_Output stage_output;
    stage_output.frag_color = frag_color;
    return stage_output;
}
