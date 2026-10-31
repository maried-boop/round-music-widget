"""Refresh the native shader from an orb-tool WebGL renderer source file."""
from pathlib import Path
import re
import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("renderer",type=Path,help="Path to the compatible orb-tool renderer.ts")
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
source=args.renderer.read_text()
glsl=source.split('export const fragmentShader = `',1)[1].split('`;',1)[0]
body=glsl[glsl.index('void main(){')+len('void main(){'):].rsplit('}',1)[0]
body=body.replace('gl_FragCoord.xy','float2(position.x,u.viewport.y-position.y)')
body=body.replace('mat2 rotation=mat2(cos(angle),-sin(angle),sin(angle),cos(angle));','float2x2 rotation=float2x2(float2(cos(angle),-sin(angle)),float2(sin(angle),cos(angle)));')
body=body.replace('atan(p.y,p.x)','atan2(p.y,p.x)')
body=body.replace('lensOffset(q,strength)','lensOffset(q,strength,lensMap)')
body=body.replace('coverAt(p)','coverAt(p,artwork)').replace('coverAt(warped)','coverAt(warped,artwork)')
body=body.replace('gl_FragColor=vec4(rgb,clamp(alpha,0.,1.));','return vec4(rgb,clamp(alpha,0.,1.));')
fields={'resolution':'viewport.xy','phase':'viewport.z','size':'viewport.w',
'body':'glass.x','light':'glass.y','rim':'glass.z','glow':'glass.w',
'width':'movement.x','motion':'movement.y','follow':'movement.z','spin':'movement.w',
'pointer':'material.xy','inside':'material.z','detail':'material.w',
'lensEnabled':'lens.x','orbEnabled':'lens.y','lensStrength':'lens.z','lensWidth':'lens.w',
'lensMotion':'lensMotion.x','lensCenter':'lensMotion.y','lensWidthMotion':'lensMotion.z','lensTravel':'lensMotion.w','lensCycles':'cycles.x',
'color1':'color1.xyz','color2':'color2.xyz','color3':'color3.xyz'}
for key,value in fields.items():body=re.sub(r'\bu_'+key+r'\b','u.'+value,body)
for a,b in [('vec2','float2'),('vec3','float3'),('vec4','float4')]:body=re.sub(r'\b'+a+r'\b',b,body)
header='''// Generated from orb tool/src/renderer.ts by scripts/sync-orb-renderer.py.
#include <metal_stdlib>
using namespace metal;
struct Uniforms {
 float4 viewport, glass, movement, material, lens, lensMotion, cycles, color1, color2, color3;
};
vertex float4 orbVertex(uint id [[vertex_id]]) {
 const float2 p[]={float2(-1,-1),float2(3,-1),float2(-1,3)};
 return float4(p[id],0,1);
}
float bell(float x,float w){return exp(-x*x/(w*w));}
float4 coverAt(float2 p,texture2d<float> artwork){
 constexpr sampler sample(coord::normalized,address::clamp_to_edge,filter::linear);
 float2 uv=clamp(p*.5+.5,0.,1.);uv.y=1.-uv.y;
 return artwork.sample(sample,uv);
}
float lensOffset(float q,float strength,texture2d<float> lensMap){
 if(abs(q)>=1.)return 0.;
 constexpr sampler sample(coord::normalized,address::clamp_to_edge,filter::linear);
 float2 uv=float2((q*.5+.5)*511./512.+.5/512.,((clamp(strength,1.,2.5)-1.)*100.+.5)/151.);
 float2 encoded=lensMap.sample(sample,uv).rg;
 return dot(encoded,float2(256.,1.))*255./65535.*4.-2.;
}
fragment float4 orbFragment(float4 position [[position]],constant Uniforms &u [[buffer(0)]],
 texture2d<float> artwork [[texture(0)]],texture2d<float> lensMap [[texture(1)]]) {
'''
(root/'Sources/RoundMusicWidget/Resources/orb-shader.txt').write_text(header+body+'\n}\n')
print('Synchronized the native Metal shader with the orb tool.')
