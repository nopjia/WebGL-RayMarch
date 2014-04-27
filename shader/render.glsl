#ifdef GL_ES
precision highp float;
#endif

/* NUMERICAL CONSTANTS */
#define EPS       0.001
#define EPS1      0.01
#define PI        3.1415926535897932
#define HALFPI    1.5707963267948966
#define QUARTPI   0.7853981633974483
#define ROOTTHREE 0.57735027
#define HUGEVAL   1e20

/* GENERAL FUNCS */
// source: inigo quilez
float maxcomp( in vec3 p ) {
  return max(p.x,max(p.y,p.z));
}
// source: http://stackoverflow.com/questions/4200224/random-noise-functions-for-glsl
float rand(in vec2 seed) {
  return fract(sin(dot(seed.xy,vec2(12.9898,78.233))) * 43758.5453);
}

/* DISTANCE FUNCS */
// source: http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm

/* PRIMITIVES */
float sdPlane( vec3 p, vec4 n )
{
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}
float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}
float sdBox( vec3 p, vec3 b ) {
  vec3  di = abs(p) - b;
  float mc = maxcomp(di);
  return min(mc,length(max(di,0.0)));
}
float udBox( vec3 p, vec3 b )
{
  return length(max(abs(p)-b,0.0));
}
float udRoundBox( vec3 p, vec3 b, float r )
{
  return length(max(abs(p)-b,0.0))-r;
}
float sdCylinder( vec3 p, vec3 c )
{
  return length(p.xz-c.xy)-c.z;
}
float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}
float lengthN(vec2 v, float n) {
  return pow(pow(v.x,n)+pow(v.y,n), 1.0/n);
}
float sdTorusN( vec3 p, vec2 t, float n )
{
  vec2 q = vec2(lengthN(p.xz,n)-t.x,p.y);
  return lengthN(q,n)-t.y;
}

/* OPERATIONS */
float opU( float d1, float d2 )
{
  return min(d1,d2);
}
float opS( float d1, float d2 )
{
  return max(-d1,d2);
}
float opI( float d1, float d2 )
{
  return max(d1,d2);
}

/* FRACTALS */

// source: http://www.iquilezles.org/www/articles/menger/menger.htm
#define ITERATIONS 3
float sdMenger(in vec3 p)
{
  float d = sdBox(p,vec3(1.0));

  float s = 1.0;
  for( int m=0; m<ITERATIONS; m++ )
  {
    vec3 a = mod( p*s, 2.0 )-1.0;
    s *= 3.0;
    vec3 r = abs(1.0 - 3.0*abs(a));
  
    float da = max(r.x,r.y);
    float db = max(r.y,r.z);
    float dc = max(r.z,r.x);
    float c = (min(da,min(db,dc))-1.0)/s;
  
    d = max(d,c);
  }
  
  return d;
}
#undef ITERATIONS

// credit the.savage@hotmail.co.uk
#define ITERATIONS 3
float sdKnot(vec3 p, float time)
{
  const vec3 offset = vec3(0.07, 0.29, 0.43);
  const vec3 clamp = vec3(-2.0,-4.0,3.0);
  
  float r=length(p.xz);
  float ang=atan(p.z,p.x);
  float y=p.y;
  float d=HUGEVAL;

  for(int n=0; n<ITERATIONS; n++) {

    vec3 p=vec3(r,y,ang+2.0*PI*float(n));
    p.x-=offset.z;

    float ra= (p.z+time)*clamp.x/clamp.z;
    float raz= p.z*clamp.y/clamp.z;

    d=min(d,length(p.xy-vec2(offset.y*cos(ra)+offset.z,offset.y*sin(raz)+offset.z))-offset.x);
  }
  return d;
}
#undef ITERATIONS

// credit the.savage@hotmail.co.uk
#define ITERATIONS 5
float sdQuaternion(vec3 p)
{
  vec4 c=vec4(0.18, 0.88, 0.24, 0.16);

  vec4 v=vec4(p,0.0);
  vec4 d=vec4(1.0,0.0,0.0,0.0);

  for(int n=1;n<ITERATIONS;n++)
  {
    d=2.0*vec4(v.x*d.x-dot(v.xzw,d.yzw),v.x*d.yzw+d.x*v.yzw+cross(v.yzw,d.yzw));
    v=vec4(v.x*v.x-dot(v.yzw,v.yzw),vec3(2.0*v.x*v.yzw))+c;

    float r=dot(v,v);

    if(r>10.0) break;
  }
  float r=length(v);
  return 0.5*r*log(r)/length(d);
}
#undef ITERATIONS


////////////////////////////////////////////////////////////
//  PROGRAM CODE
////////////////////////////////////////////////////////////

/* SHADER VARS */
varying vec2 vUv;

uniform vec3 uCamCenter;
uniform vec3 uCamPos;
uniform vec3 uCamUp;
uniform float uAspect;
uniform float uTime;
uniform vec3 uLightP;

/* PROGRAM CONSTANTS */
const float c_fBounds = 15.0;
const float c_fSmooth = 0.70;
const float c_fDither = 0.001;

const vec3 c_vFogColor = vec3(0.6, 0.6, 0.7);
const vec3 c_vMaterial0 = vec3(0.5);
const vec3 c_vMaterial1 = vec3(0.9, 0.7, 0.5);
const vec3 c_vMaterial2 = vec3(0.3, 0.5, 1.0);

/* GLOBAL VARS */
float gMin = 0.0;
float gMax = HUGEVAL;

// ray tracing globals
vec3 currCol = c_vMaterial2;
float currSSS = 1.0;
bool currHit = false;
vec3 currPos, currNor;

//#define DE_WARP
//#define DE_ROTATE
//#define DE_TWIST
//#define DE_DISPLACE
//#define DE_GROUND

//#define DE_BOX
//#define DE_ROUNDBOX
//#define DE_USHAPE
//#define DE_MENGER
//#define DE_KNOT
//#define DE_QUATERNION

float getDist(in vec3 p) {
  #ifdef DE_WARP
  // warpping xz plane
  p.x = mod(p.x,5.0)-2.5;
  p.z = mod(p.z,5.0)-2.5;
  #endif
  
  vec3 p1 = p;
  
  #ifdef DE_ROTATE
  // rotation matrix
  mat3 rotateY = mat3(
    cos(uTime),   0.0,  sin(uTime),
    0.0,          1.0,  0.0,       
    -sin(uTime),  0.0,  cos(uTime)
  );
  mat3 rotateX = mat3(
    1.0, 0.0, 0.0,
    0.0, cos(uTime), sin(uTime), 
    0.0, -sin(uTime), cos(uTime)
  );
  p1 = rotateY*rotateX*p;
  #endif
  
  #ifdef DE_TWIST
  // twist
  float twist = sin(2.0*uTime);
  float c = cos(twist*p1.y);
  float s = sin(twist*p1.y);
  mat2  m = mat2(c,-s,s,c);
  p1 = vec3(m*p1.xz,p1.y);
  #endif
    
  /* SCENE CONSTRUCTION */

  float d0 = HUGEVAL;
  float d1 = HUGEVAL;
  
  #ifdef DE_KNOT
  d0 = sdKnot(p1/2.0, 2.0*uTime)*2.0;
  #endif
  
  #ifdef DE_QUATERNION
  d0 = sdQuaternion(p1/2.0)*2.0;
  #endif
  
  #ifdef DE_MENGER
  d0 = sdMenger(p1/2.0)*2.0;
  #endif
  
  #ifdef DE_BOX
  d0 = sdBox(p1, vec3(1.0));
  #endif
  
  #ifdef DE_ROUNDBOX
  d0 = udRoundBox(p1, vec3(1.0), 0.2);
  #endif
  
  #ifdef DE_USHAPE
  // ushape box
  d0 = sdBox(p1,vec3(2.0, 2.0, 1.0));
  d1 = sdSphere(p1-vec3(0.0, 1.5, 0.0), 1.5);
  d0 = opS(d1, d0);
  #endif  
  
  #ifdef DE_DISPLACE
  float d2 = 0.3*sin(PI*p1.x)*sin(PI*p1.y)*sin(PI*p1.z);
  d0 += d2;
  #endif
  
  //// twisted box
  //float c = cos(QUARTPI*p1.y);
  //float s = sin(QUARTPI*p1.y);
  //mat2  m = mat2(c,-s,s,c);
  //vec3  q = vec3(m*p.xz,p1.y);
  //d0 = sdBox(q,vec3(1.0, 2.0, 2.0));
    
  #ifdef DE_GROUND
  // ground plane
  d1 = sdPlane(p+vec3(0.0,3.0,0.0), vec4(0.0,1.0,0.0,0.0));
  if (d1<d0) {
    d0 = d1;
    currCol = c_vMaterial0;
    currSSS = 0.0;
  }
  else {
    d0 = d0;
    currCol = c_vMaterial2;
    currSSS = 1.0;
  }
  #else
  // hack fix error wtf
  d1 = p.z*p.z+HUGEVAL;
  d0 = d1 < d0 ? d1 : d0;
  #endif
  
  return d0;
}

// source: inigo quilez
// normal from central difference
vec3 getNormal(in vec3 pos) {
  vec3 eps = vec3(EPS, 0.0, 0.0);
  vec3 nor;
  nor.x = getDist(pos+eps.xyy) - getDist(pos-eps.xyy);
  nor.y = getDist(pos+eps.yxy) - getDist(pos-eps.yxy);
  nor.z = getDist(pos+eps.yyx) - getDist(pos-eps.yyx);
  return normalize(nor);
}

bool intersectBounds (in vec3 ro, in vec3 rd) {
  float B = dot(ro,rd);
  float C = dot(ro,ro) - c_fBounds;
  
  float d = B*B - C;  // discriminant
  
  if (d<0.0) return false;
  
  d = sqrt(d); // dist
  B = -B;
  gMin = max(0.0, B-d);
  gMax = B+d;
  
  return true;
}
int intersectSteps(in vec3 ro, in vec3 rd) {  
  float t = 0.0;
  int steps = -1;  
  
  for(int i=0; i<MAX_STEPS; ++i)
  {
    float dt = getDist(ro + rd*t) * c_fSmooth;
    if(dt >= EPS) {
      steps++;
    }
    else {
      break;
    }
    t += dt;
  }
  return steps;
}
float intersectDist(in vec3 ro, in vec3 rd) {  
  float t = gMin;
  float dist = -1.0;
  
  for(int i=0; i<MAX_STEPS; ++i)
  {
    float dt = getDist(ro + rd*t) * c_fSmooth;
    
    if(dt < EPS) {
      dist = t;
      break;
    }
    
    t += dt;    
    
    if(t > gMax)
      break;
  }
  
  return dist;
}

// source: the.savage@hotmail.co.uk
#define SS_K  15.0
float getShadow (in vec3 pos, in vec3 toLight) {
  float shadow = 1.0;
  float lightDist = distance(uLightP,pos);

  float t = EPS1;
  float dt;

  for(int i=0; i<MAX_STEPS; ++i)
  {
    dt = getDist(pos+(toLight*t)) * c_fSmooth;
    
    if(dt < EPS)    // stop if intersect object
      return 0.0;

    shadow = min(shadow, SS_K*(dt/t));
    
    t += dt;
    
    if(t > lightDist)   // stop if reach light
      break;
  }
  
  return clamp(shadow, 0.0, 1.0);
}

#define AO_K      1.5
#define AO_DELTA  0.2
#define AO_N      5
float getAO (in vec3 pos, in vec3 nor) {
  float sum = 0.0;
  float weight = 0.5;
  float delta = AO_DELTA;
  
  for (int i=0; i<AO_N; ++i) {
    sum += weight * (delta - getDist(pos+nor*delta));
    
    delta += AO_DELTA;
    weight *= 0.5;
  }
  return clamp(1.0 - AO_K*sum, 0.0, 1.0);
}

#define SSS_K      1.5
#define SSS_DELTA  0.3
#define SSS_N      5
float getSSS (in vec3 pos, in vec3 look) {
  float sum = 0.0;
  float weight = -0.5;
  float delta = SSS_DELTA;
  
  for (int i=0; i<SSS_N; ++i) {
    sum += weight * min(0.0, getDist(pos+look*delta));
    
    delta += delta;
    weight *= 0.5;
  }
  return clamp(SSS_K*sum, 0.0, 1.0);
}

//#define CHECK_BOUNDS
//#define RENDER_DIST
//#define RENDER_STEPS

//#define FX_DIFFUSE
//#define FX_REFLECTION
//#define FX_OCCLUSION
//#define FX_SUBSURFACE
//#define FX_SHADOW
//#define FX_FOG
//#define FX_DITHER

#define KA  0.1
#define KD  0.9
#define KR  0.3

vec3 rayMarch (in vec3 ro, in vec3 rd) {
  
  #ifdef CHECK_BOUNDS
  if (intersectBounds(ro, rd)) {
  #endif
    
    #ifdef RENDER_STEPS
    int steps = intersectSteps(ro, rd);  
    return vec3(float(MAX_STEPS-steps)/float(MAX_STEPS));
    #else
    
    float t = intersectDist(ro, rd);
        
    if (t>0.0) {      
      #ifdef RENDER_DIST
      const float maxDist = 20.0;
      t = min(t, maxDist);
      return vec3((maxDist-t)/maxDist);
      #else
      
      vec3 pos = ro + rd*t;
      vec3 nor = getNormal(pos-rd*EPS);
      
      // save global values first before getShadow change them
      vec3 col = currCol;      
      float sss = currSSS;
      
      #ifdef FX_DIFFUSE
      // diffuse lighting
      vec3 toLight = normalize(uLightP-pos);
      float shadow = 1.0; 
      #ifdef FX_SHADOW
      shadow = getShadow(pos, toLight);
      #endif
      col *= (KA + KD*max(dot(toLight,nor),0.0)*shadow);
      #endif
      
      #ifdef FX_OCCLUSION
      // Ambient Occlusion
      float ao = getAO(pos, nor);
      col *= ao;
      #endif
      
      #ifdef FX_SUBSURFACE
      /// Subsurface Scattering
      sss *= getSSS(pos, rd);
      col *= 1.0-sss;
      #endif
    
      #ifdef FX_FOG
      // Add Fog
      float fogAmount = exp(-0.05*t);
      col *= fogAmount;
      #endif
            
      currHit = true;
      currPos = pos;
      currNor = nor;
      
      return col;
      #endif // RENDER_DIST
    }
    #endif // RENDER_STEPS
    
    currHit = false;
  
  #ifdef CHECK_BOUNDS
  }
  #endif
  
  return vec3(0.0);
}

vec3 render (in vec3 ro, in vec3 rd) {
  vec3 col = rayMarch(ro, rd);
  
  #ifdef FX_REFLECTION
  if (currHit) {
    vec3 reflRay = reflect(rd, currNor);
    col = col*(1.0-KR) + rayMarch(currPos+reflRay*EPS1, reflRay)*KR;
  }
  #endif
  
  return col;
}

////////////////////////////////////////////////////////////
//  MAIN
////////////////////////////////////////////////////////////

void main(void) {  
  /* CAMERA RAY */
  vec3 C = normalize(uCamCenter-uCamPos);
  vec3 A = uAspect*normalize(cross(C,uCamUp));
  vec3 B = -normalize(uCamUp);
  
  // scale A and B by root3/3 : fov = 30 degrees
  // vec3 ro = uCamPos+C + (2.0*vUv.x-1.0)*ROOTTHREE*A + (2.0*vUv.y-1.0)*ROOTTHREE*B;
  // vec3 rd = normalize(ro-uCamPos);
  // ro = uCamPos;
  vec3 rd = normalize( C + (2.0*vUv.x-1.0)*ROOTTHREE*A + (2.0*vUv.y-1.0)*ROOTTHREE*B );
  vec3 ro = uCamPos;
    
  #ifdef FX_DITHER
  // dithered
  float t = intersectDist(ro, rd);
  vec2 uv = vUv;
  float dither = t*t*c_fDither;
  uv.x += rand(vUv+vec2(.12, .32))*dither - dither/2.0;
  uv.y += rand(vUv+vec2(.42, .52))*dither - dither/2.0;
  ro = uCamPos+C + (2.0*uv.x-1.0)*ROOTTHREE*A + (2.0*uv.y-1.0)*ROOTTHREE*B;
  #endif
  
  // rendering
  gl_FragColor.a = 1.0;
  gl_FragColor.rgb = render(ro, rd);
}