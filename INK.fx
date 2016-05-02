//--------------------------------------------------------------
// INK  proportionate colour difference keyer
// Copyright 2016 Nicholas Carroll 
// http://casanico.com
//
// INK is free software: you can redistribute it and/or modify it under the terms
// of the GNU General Public License published by the Free Software Foundation;
// either version 3 of the License, or (at your option) any later version. See
// http://www.gnu.org/licenses/gpl-3.0.html
//--------------------------------------------------------------
int _LwksEffectInfo
<
   string EffectGroup = "GenericPixelShader";
   string Description = "INK";
   string Category    = "Keying";
> = 0;

//--------------------------------------------------------------
// Inputs
//--------------------------------------------------------------
texture fg;
texture bg;

sampler FgSampler = sampler_state { Texture = <fg>; };
sampler BgSampler = sampler_state { Texture = <bg>; };

//--------------------------------------------------------------
// Parameters
//--------------------------------------------------------------

float4 keyColor
<
   string Description = "Key Colour";
> = { 0.2, 1.0, 0.0, 1.0 };

float bal
<
   string Description = "Key Balance";
   float MinVal = 0.0;
   float MaxVal = 1.00;
> = 0.5;

#pragma warning ( disable : 3571 )

//--------------------------------------------------------------
// Shader
//--------------------------------------------------------------

half4 MyFunction(float2 xy : TEXCOORD1) : COLOR {
    float4 color, foreground = tex2D(FgSampler, xy.xy);
    float4 background  = tex2D(BgSampler, xy.xy);
    float matte = 1.;
    int minKey = 0; 
    int midKey = 1; 
    int maxKey = 2;
    
    if(keyColor.b <= keyColor.r && keyColor.r <= keyColor.g ){
      minKey = 2; 
      midKey = 0; 
      maxKey = 1; 
    } else if (keyColor.r <= keyColor.b && keyColor.b <= keyColor.g ){
      minKey = 0; 
      midKey = 2; 
      maxKey = 1; 
    } else if (keyColor.g <= keyColor.b && keyColor.b <= keyColor.r ){
      minKey = 1; 
      midKey = 2; 
      maxKey = 0; 
    } else if (keyColor.g <= keyColor.r && keyColor.r <= keyColor.b ){
      minKey = 1; 
      midKey = 0; 
      maxKey = 2; 
    } else if (keyColor.b <= keyColor.g && keyColor.g <= keyColor.r ){
      minKey = 2; 
      midKey = 1; 
      maxKey = 0; 
    }
    float K[3] = {keyColor.r, keyColor.g, keyColor.b};
    float  chan[3] , P[3] = {foreground.r, foreground.g, foreground.b};

    // solve chan[minKey]		
    float min1 = (P[minKey]/(P[maxKey]-bal*P[midKey])-K[minKey]/(K[maxKey]-bal*K[midKey]))
		      / (1+P[minKey]/(P[maxKey]-bal*P[midKey])-(2-bal)*K[minKey]/(K[maxKey]-bal*K[midKey]));
     float min2 = min(P[minKey],(P[maxKey]-bal*P[midKey])*min1/(1-min1));    
    chan[minKey] = max(0.,min(min2,1.));
    // solve chan[midKey]
    float mid1 = (P[midKey]/(P[maxKey]-(1-bal)*P[minKey])-K[midKey]/(K[maxKey]-(1-bal)*K[minKey]))
		     / (1+P[midKey]/(P[maxKey]-(1-bal)*P[minKey])-(1+bal)*K[midKey]/(K[maxKey]-(1-bal)*K[minKey]));
    float mid2 = min(P[midKey],(P[maxKey]-(1-bal)*P[minKey])*mid1/(1-mid1));
    chan[midKey] = max(0.,min(mid2,1.));
    // solve chan[maxKey]
    float max1 = min(P[maxKey],(bal*min(P[midKey],(P[maxKey]-(1-bal)*P[minKey])*mid1/(1-mid1))
					 + (1-bal)*min(P[minKey],(P[maxKey]-bal*P[midKey])*min1/(1-min1))));
    chan[maxKey] = max(0.,min(max1,1.));
    // solve alpha
    float a1 = (1-K[maxKey])+(bal*K[midKey]+(1-bal)*K[minKey]);
    float a2 = 1+a1/abs(1-a1);
    float a3 =  (1-P[maxKey])-P[maxKey]*(a2-(1+(bal*P[midKey]+(1-bal)*P[minKey])/P[maxKey]*a2));
    float a4 = max(chan[midKey],max(a3,chan[minKey]));
    matte = max(0.,min(a4,1.)); //alpha

    color.r = chan[0] + background.r * (1 - matte);
    color.g = chan[1] + background.g * (1 - matte);
    color.b = chan[2] + background.b * (1 - matte);

	return color;
}

technique MyTechnique
{
   pass p0
   {
      PixelShader = compile PROFILE MyFunction();
   }
}

