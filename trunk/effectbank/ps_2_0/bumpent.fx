// Fake Bump (uses a normal map to extract a specular map) (entity bump)

/************* UNTWEAKABLES **************/

float4x4 World      : WORLD;

float4x4 WorldViewProj : WorldViewProjection;
float4x4 WorldView : WorldView;
float4x4 WorldIT : WorldInverseTranspose;
float4x4 ViewInv : ViewInverse;
float4 eyePos : CameraPosition;
float time : Time;
float4 clipPlane : ClipPlane;


/******TWEAKABLES***************************/

float depthScale
<
	string UIWidget = "slider";
	float UIMax = 0.1;
	float UIMin = 0.001;
	float UIStep = 0.001;
> = 0.015;

/*********** SPOTFLASH VALUES FROM FPSC **********/

float4 SpotFlashPos;


float4 SpotFlashColor;


float SpotFlashRange   //fixed value that FPSC uses
<
    string UIName =  "SpotFlash Range";
    
> = {600.00};

/******VALUES PULLED FROM FPSC - NON TWEAKABLE**********/

float4 AmbiColor : Ambient
<
    string UIName =  "Ambient Light Color";
> = {0.1f, 0.1f, 0.1f, 1.0f};

float4 SurfColor : Diffuse
<
    string UIName =  "Surface Color";
    string UIType = "Color";
> = {1.0f, 1.0f, 1.0f, 1.0f};

float4 LightSource
<
    string UIType = "Fixed Light Source";
> = {5000.0f,100.0f, -0.0f, 1.0f};




/****************** TEXTURES AND SAMPLERS*********************/

texture DiffuseMap : DiffuseMap
<
    string Name = "D.tga";
    string type = "2D";
>;

texture EffectMap : DiffuseMap
<
    string Name = "I.tga";
    string type = "2D";
>;

//Diffuse Texture
sampler2D DiffuseSampler = sampler_state
{
    Texture   = <DiffuseMap>;
    MipFilter = LINEAR;
    MinFilter = ANISOTROPIC;
    MagFilter = LINEAR;
};

//Effect Texture
sampler2D EffectSampler = sampler_state
{
    Texture   = <EffectMap>;
    MipFilter = LINEAR;
    MinFilter = ANISOTROPIC;
    MagFilter = LINEAR;
};

/************* DATA STRUCTS **************/

struct appdata {
    float4 Position	: POSITION;
    float4 UV0		: TEXCOORD0;
    float4 UV1		: TEXCOORD1;
    float4 Normal	: NORMAL;
    float4 Tangent	: TANGENT0;
    float4 Binormal	: BINORMAL0;
};

/*data passed to pixel shader*/
struct vertexOutput
{
    float4 Position    : POSITION;
    float2 TexCoord     : TEXCOORD0;
    float2 TexCoordLM   : TEXCOORD1;
    float3 LightVec	    : TEXCOORD2;
    float3 WorldNormal	: TEXCOORD3;
    float4 WPos : TEXCOORD4;
    float4 ppos : TEXCOORD5;
    float clip : TEXCOORD6;
};


/*******Vertex Shader***************************/

vertexOutput mainVS(appdata IN)   
{
    vertexOutput OUT;   
    float4 worldSpacePos = mul(IN.Position, World);
    OUT.WorldNormal = normalize(mul(IN.Normal, WorldIT).xyz);
    OUT.LightVec = normalize (eyePos+25 - worldSpacePos );  //adding in a slight offset to eyePos for some variation to spec position
    OUT.Position = mul(IN.Position, WorldViewProj);
    OUT.TexCoord  = IN.UV0; 
    OUT.TexCoordLM  = IN.UV1; 
    OUT.WPos =   worldSpacePos;                                                                                
    OUT.ppos = mul( IN.Position, WorldView );                           
    // all shaders should send the clip value to the pixel shader (for refr/refl)                                                                     
    OUT.clip = dot(worldSpacePos, clipPlane);
    return OUT;
}

/****************Framgent Shader*****************/

float4 CalcSpotFlash( float3 worldNormal, float3 worldPos )
{
    float4 output = (float4)0.0;
    float3 toLight = SpotFlashPos.xyz - worldPos.xyz;
    float3 lightDir = normalize( toLight );
    float lightDist = length( toLight );
    
    float MinFalloff = 200;  //falloff start distance - 50,0,.01 are very cool too for lanterns
    float LinearFalloff = 1;
    float ExpFalloff = .005;  // 1/200
    
    float fAtten = 1.0/(MinFalloff + (LinearFalloff*lightDist)+(ExpFalloff*lightDist*lightDist));
    
    SpotFlashPos.w = clamp(0,1,SpotFlashPos.w -.2);
    
    
    output += max(0,dot( lightDir, worldNormal ) * 2.5*SpotFlashColor*fAtten * (SpotFlashPos.w) );
    
    return output;
}

float4 mainPS(vertexOutput IN) : COLOR
{
    // all shaders should receive the clip value                                                                
    clip(IN.clip);

    float4 diffuse = tex2D(DiffuseSampler,IN.TexCoord.xy);    //sample diffuse texture    
    float4 effectmap = tex2D(EffectSampler,IN.TexCoord.xy);   //sample specular map texture 
    float3 Ln = (IN.LightVec);
    float3 Nn = normalize(IN.WorldNormal);
    float3 V  = normalize(eyePos - IN.WPos);                  //create normalized view vector for constant forward "hero" spec
    float3 Hn = normalize(V+Ln);                              //half vector
    float dis = distance(IN.WPos,eyePos);
    float atten = (1/(dis*(dis*.01)))* 2000 ;                 //last value is multiplier, inverse square faloff
    atten = clamp(atten,0,1.5);                               //second value controls how bright to let the highlights become
    float herospec = pow(max(dot(Nn,Hn),0),10);               //specular highlights 
    float4 fakespecmap = float4((effectmap.z-((abs(effectmap.x-0.5)+abs(effectmap.y-0.5))*3)).xxx,1);
    float4 specular = (AmbiColor+SurfColor)*(herospec)*(fakespecmap*1)*diffuse*atten; //multiply spec texture, lightmap, and diffuse texture
    float4 spotflashlighting = CalcSpotFlash ( IN.WorldNormal, IN.WPos.xyz );
    float4 LMfinal = (spotflashlighting+AmbiColor+SurfColor)*diffuse;
    float4 result =   LMfinal + specular;
    return result;
}

technique alpha
{
    pass P0
    {
        Lighting       = FALSE;
        FogEnable      = FALSE;
        VertexShader = compile vs_2_0 mainVS();
        PixelShader  = compile ps_2_0 mainPS();
    }
}
