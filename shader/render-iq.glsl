// See http://www.iquilezles.org/articles/menger/menger.htm for the 
// full explanation of how this was done

#ifdef GL_ES
precision highp float;
#endif

/* CONSTANTS */
#define EPS       0.001
#define EPS1      0.01
#define PI        3.14159265
#define HALFPI    1.57079633
#define QUARTPI   0.78539816
#define ROOTTHREE 0.57735027
#define HUGE_VAL  10000000000.0

/* SHADER VARS */
varying vec2 vUv;

uniform vec3 uCamCenter;
uniform vec3 uCamPos;
uniform vec3 uCamUp;
uniform float uAspect;
uniform vec3 uLightP;

float maxcomp(in vec3 p ) { return max(p.x,max(p.y,p.z));}
float sdBox( vec3 p, vec3 b )
{
  vec3  di = abs(p) - b;
  float mc = maxcomp(di);
  return min(mc,length(max(di,0.0)));
}
float sdPlane( vec3 p, vec4 n )
{
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}

vec4 map( in vec3 p )
{
  //float d = sdPlane(p,vec4(0.0, 1.0, 0.0, 0.0));
  
  float c = cos(QUARTPI/2.0*p.y);
  float s = sin(QUARTPI/2.0*p.y);
  mat2  m = mat2(c,-s,s,c);
  p = vec3(m*p.xz,p.y);
  
  float d = sdBox(p,vec3(1.0));
  vec4 res = vec4( d, 1.0, 0.0, 0.0 );

  return res;
}

// GLSL ES doesn't seem to like loops with conditional break/return...
#if 0
vec4 intersect( in vec3 ro, in vec3 rd )
{
  float t = 0.0;
  for(int i=0;i<64;i++)
  {
    vec4 h = map(ro + rd*t);
    if( h.x<0.002 ) 
    return vec4(t,h.yzw);
    t += h;
  }
  return vec4(-1.0);
}
#else
vec4 intersect( in vec3 ro, in vec3 rd )
{
  float t = 0.0;
  vec4 res = vec4(-1.0);
  for(int i=0;i<64;i++)
  {
    vec4 h = map(ro + rd*t);
    if( h.x<0.002 ) 
    {
      if( res.x<0.0 ) res = vec4(t,h.yzw);
    }
    //if( h.x>0.0 )
    t += h;
  }
  return res;
}
#endif

vec3 calcNormal(in vec3 pos)
{
  vec3  eps = vec3(.001,0.0,0.0);
  vec3 nor;
  nor.x = map(pos+eps.xyy).x - map(pos-eps.xyy).x;
  nor.y = map(pos+eps.yxy).x - map(pos-eps.yxy).x;
  nor.z = map(pos+eps.yyx).x - map(pos-eps.yyx).x;
  return normalize(nor);
}

void main(void)
{
  /* CAMERA RAY */
  vec3 C = normalize(uCamCenter-uCamPos);
  vec3 A = normalize(cross(C,uCamUp));
  vec3 B = -1.0/uAspect*normalize(cross(A,C));
  
  // scale A and B by root3/3 : fov = 30 degrees
  vec3 ro = uCamPos+C + (2.0*vUv.x-1.0)*ROOTTHREE*A + (2.0*vUv.y-1.0)*ROOTTHREE*B;
  vec3 rd = normalize(ro-uCamPos);

  // light
  vec3 light = normalize(vec3(1.0,0.8,-0.6));

  vec3 col = vec3(0.0);
  vec4 tmat = intersect(ro,rd);
  if( tmat.x>0.0 )
  {
    vec3 pos = ro + tmat.x*rd;
    vec3 nor = calcNormal(pos);

    float dif1 = max(0.4 + 0.6*dot(nor,light),0.0);
    float dif2 = max(0.4 + 0.6*dot(nor,vec3(-light.x,light.y,-light.z)),0.0);

    // shadow
    float ldis = 4.0;
    vec4 shadow = intersect( pos + light*ldis, -light );
    if( shadow.x>0.0 && shadow.x<(ldis-0.01) ) dif1=0.0;


    float ao = tmat.y;
    col  = 1.0*ao*vec3(0.2,0.2,0.2);
    col += 2.0*(0.5+0.5*ao)*dif1*vec3(1.0,0.97,0.85);
    col += 0.2*(0.5+0.5*ao)*dif2*vec3(1.0,0.97,0.85);
    col += 1.0*(0.5+0.5*ao)*(0.5+0.5*nor.y)*vec3(0.1,0.15,0.2);

    // gamma lighting
    //col = col*0.5+0.5*sqrt(col)*1.2;


    vec3 matcol = vec3(
    0.6+0.4*cos(5.0+6.2831*tmat.z),
    0.6+0.4*cos(5.4+6.2831*tmat.z),
    0.6+0.4*cos(5.7+6.2831*tmat.z) );
    col *= matcol;
    col *= 1.5*exp(-0.5*tmat.x);

  }


  gl_FragColor = vec4(col,1.0);
}