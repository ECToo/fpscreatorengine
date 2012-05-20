//
// Illumination Map
//

string XFile = "sphere.x";   // model
int    BCLR = 0xff202080;   // background

// light direction (view space)
float3 lightDir <  string UIDirectional = "Light Direction"; > = {0.577, -0.577, 0.577};
float4 AmbiColor : Ambient
<
    string UIName =  "Ambient Light Color";
> = {0.1f, 0.1f, 0.1f, 1.0f};

//----------------
// FOG sensitivity
//----------------
float4 FogColor : Diffuse
<
    string UIName =  "Fog Color";
    string UIType = "Color";
> = {0.0f, 0.0f, 0.0f, 0.0000001f};

// light intensity
float4 I_a = { 0.1f, 0.1f, 0.1f, 1.0f };    // ambient
float4 I_d = { 1.0f, 1.0f, 1.0f, 1.0f };    // diffuse
float4 I_s = { 1.0f, 1.0f, 1.0f, 1.0f };    // specular

// material reflectivity
float4 k_d : MATERIALDIFFUSE = { 1.0f, 1.0f, 1.0f, 1.0f };    // diffuse
float4 k_s : MATERIALSPECULAR= { 0.0f, 0.0f, 0.0f, 0.0f };    // specular
int    n   : MATERIALPOWER = 32;                            // power

// texture
texture Tex0 < string name = "lm.tga"; >;
texture Tex1 < string name = "base.tga"; >;
texture Tex2 < string name = "illumination.tga"; >;

// transformations
float4x4 World      : WORLD;
float4x4 View       : VIEW;
float4x4 Projection : PROJECTION;
float4 clipPlane : ClipPlane;

struct VS_OUTPUT
{
    float4 Pos  : POSITION;
    float4 Diff : COLOR0;
    float2 Tex  : TEXCOORD0;
    float2 Tex2  : TEXCOORD1;
    float2 Tex3  : TEXCOORD2;
    float Fog : TEXCOORD3;  
    float clip : TEXCOORD4;
};

VS_OUTPUT VS(
    float3 Pos  : POSITION, 
    float3 Norm : NORMAL, 
    float2 Tex  : TEXCOORD0, 
    float2 Tex2 : TEXCOORD1)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    float4x4 WorldView = mul(World, View);
    float3 P = mul(float4(Pos, 1), (float4x3)WorldView);  // position (view space)
    Out.Pos  = mul(float4(P, 1), Projection);             // position (projected)
    Out.Diff = AmbiColor; 		  // ambient
    Out.Diff.w = 1.0f;
    Out.Tex  = Tex;                                       
    Out.Tex2  = Tex;                                       
    Out.Tex3  = Tex2;

    // calculate FOG colour
    float4 worldSpacePos = mul(float4(Pos,1), World);                                                     
    float4 cameraPos = mul( worldSpacePos, View );
    float fogstrength = cameraPos.z * FogColor.w;
    Out.Fog = min(fogstrength,1.0);

    // all shaders should send the clip value to the pixel shader (for refr/refl)
    Out.clip = dot(worldSpacePos, clipPlane);

    return Out;
}

sampler Sampler = sampler_state
{
    Texture   = (Tex0);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler Sampler2 = sampler_state
{
    Texture   = (Tex1);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler Sampler3 = sampler_state
{
    Texture   = (Tex2);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

float4 PS(VS_OUTPUT IN) : COLOR
{
    clip(IN.clip);
    float4 result = (tex2D(Sampler, IN.Tex3)+IN.Diff+tex2D(Sampler3, IN.Tex2)) * tex2D(Sampler2, IN.Tex);
    return float4((result.xyz*(1-IN.Fog))+(FogColor.xyz*IN.Fog),1);
}

technique TVertexShaderOnly
{
    pass P0
    {
        // lighting
        Lighting       = FALSE;
        FogEnable      = FALSE;

        // samplers
        Sampler[0] = (Sampler);
        Sampler[1] = (Sampler2);
        Sampler[2] = (Sampler3);

        // shaders
        VertexShader = compile vs_1_0 VS();
        PixelShader  = compile ps_2_0 PS();
    }
}
