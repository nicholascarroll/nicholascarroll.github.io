//--------------------------------------------------------------//
// INK  proportionate colour difference keyer
// Copyright 2016 Nicholas Carroll 
// http://casanico.com
//
// INK is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License published
// by the Free Software Foundation; either version 3 of the
// License, or (at your option) any later version. See
// http://www.gnu.org/licenses/gpl-3.0.html
//
// This version reworked to remove array indexing which didn't
// work in Lightworks by forum moderator jwrl May 2 2016.
//--------------------------------------------------------------//

int _LwksEffectInfo
<
   string EffectGroup = "GenericPixelShader";
   string Description = "INK";
   string Category    = "Keying";
> = 0;

//--------------------------------------------------------------//
// Inputs
//--------------------------------------------------------------//

texture fg;
texture bg;

sampler FgSampler = sampler_state { Texture = <fg>; };
sampler BgSampler = sampler_state { Texture = <bg>; };

//--------------------------------------------------------------//
// Parameters
//--------------------------------------------------------------//

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

//--------------------------------------------------------------//
// Shader
//--------------------------------------------------------------//

float4 MyFunction (float2 xy : TEXCOORD1) : COLOR
{
   float4 foreground = tex2D (FgSampler, xy);
   float4 background = tex2D (BgSampler, xy);

   float3 chan, P = foreground.rgb;
   float3 K = keyColor.rgb;

   float nbal = 1 - bal;

   int minKey = 0;
   int midKey = 1;
   int maxKey = 2;

   if (keyColor.b <= keyColor.r && keyColor.r <= keyColor.g) {
      minKey = 2;
      midKey = 0;
      maxKey = 1;
      P = foreground.brg;
      K = keyColor.brg;
   }
   else if (keyColor.r <= keyColor.b && keyColor.b <= keyColor.g) {
      minKey = 0;
      midKey = 2;
      maxKey = 1;
      P = foreground.rbg;
      K = keyColor.rbg;
   }
   else if (keyColor.g <= keyColor.b && keyColor.b <= keyColor.r) {
      minKey = 1;
      midKey = 2;
      maxKey = 0;
      P = foreground.gbr;
      K = keyColor.gbr;
   }
   else if (keyColor.g <= keyColor.r && keyColor.r <= keyColor.b) {
      minKey = 1;
      midKey = 0;
      maxKey = 2;
      P = foreground.grb;
      K = keyColor.grb;
   }
   else if (keyColor.b <= keyColor.g && keyColor.g <= keyColor.r) {
      minKey = 2;
      midKey = 1;
      maxKey = 0;
      P = foreground.bgr;
      K = keyColor.bgr;
   }

   // solve minKey

   float min1 = (P.x / (P.z - bal * P.y) - K.x / (K.z - bal * K.y))
              / (1 + P.x / (P.z - bal * P.y) - (2 - bal) * K.x / (K.z - bal * K.y));
   float min2 = min (P.x, (P.z - bal * P.y) * min1 / (1 - min1));

   if (minKey == 0) chan.r = saturate (min2);
   else if (minKey == 1) chan.g = saturate (min2);
   else chan.b = saturate (min2);

   // solve midKey

   float mid1 = (P.y / (P.z - nbal * P.x) - K.y / (K.z - nbal * K.x)) 
              / (1 + P.y / (P.z - nbal * P.x) - (1 + bal) * K.y / (K.z - nbal * K.x));
   float mid2 = min (P.y, (P.z - nbal * P.x) * mid1 / (1 - mid1));

   if (midKey == 0) chan.r = saturate (mid2);
   else if (midKey == 1) chan.g = saturate (mid2);
   else chan.b = saturate (mid2);

   // solve chan.z (chan [maxKey])

   float max1 = min (P.z, (bal * min (P.y, (P.z - nbal * P.x) * mid1 / (1 - mid1))
              + nbal * min (P.x, (P.z - bal * P.y) * min1 / (1 - min1))));

   if (maxKey == 0) chan.r = saturate (max1);
   else if (maxKey == 1) chan.g = saturate (max1);
   else chan.b = saturate (max1);

   // solve alpha

   float a1 = (1 - K.z) + (bal * K.y + (1 - bal) * K.x);
   float a2 = 1 + a1 / abs (1 - a1);
   float a3 = (1 - P.z) - P.z * (a2 - (1 + (bal * P.y + (1 - bal) * P.x) / P.z * a2));
   float a4 = max (chan.g, max (a3, chan.b));

   float matte = 1 - saturate (a4);          // alpha

   return float4 ((chan + background.rgb * matte), 1.0);
}

//--------------------------------------------------------------//
// Techniques
//--------------------------------------------------------------//

technique MyTechnique
{
   pass p0
   {
      PixelShader = compile PROFILE MyFunction ();
   }
}

