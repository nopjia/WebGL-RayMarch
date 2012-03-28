#ifdef GL_ES
precision highp float;
#endif

/* CONSTANTS */
#define EPS     0.0001
#define PI      3.14159265
#define HALFPI  1.57079633
#define ROOTTHREE 0.57735027
#define HUGE_VAL  1000000000.0

////////////////////////////////////////////////////////////////////////////////
// SHAPE 
////////////////////////////////////////////////////////////////////////////////
struct Shape {  
  bool geometry;
  vec3 pos;
  float radius;
  vec3 color;
};
Shape newShape(bool t, vec3 p, float r, vec3 c) {
  Shape s = Shape(t, p, r, c);
  return s;
}
Shape newSphere() {
  return Shape(false, vec3(0.0), 0.5, vec3(0.5, 0.5, 0.5));
}
Shape newSphere(vec3 p, float r, vec3 c) {
  Shape s = Shape(false, p, r, c);
  return s;
}
Shape newCube() {
  return Shape(true, vec3(0.0), 0.5, vec3(0.5, 0.5, 0.5));
}
Shape newCube(vec3 p, float r, vec3 c) {
  Shape s = Shape(true, p, r, c);
  return s;
}
bool intersect(Shape s, vec3 P, vec3 V, out float t) {
  
  vec3 dist = P-s.pos;
  
  if (!s.geometry) {
    float A = dot(V,V);
    float B = 2.0 * dot(dist,V);    
    float C = dot(dist,dist) - s.radius*s.radius;
    
    float d = B*B - 4.0*A*C;  // discriminant
    if (d < 0.0) return false;
    
    d = sqrt(d);
    t = (-B-d)/(2.0*A);
    if (t > 0.0) {
      return true;
    }
    
    t = (-B+d)/(2.0*A);
    if (t > 0.0) {
      return true;
    }
    
    return false;
  }
  else {    
    vec3 tMin = ( (s.pos-vec3(s.radius)) - P ) / V;
    vec3 tMax = ( (s.pos+vec3(s.radius)) - P ) / V;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    
    if (tNear<tFar && tFar>0.0) {
      t = tNear>0.0 ? tNear : tFar;
      return true;
    }
    
    return false;
  }
}
vec3 getNormal(Shape s, vec3 hit) {
  if (!s.geometry) {
    return (hit-s.pos)/s.radius;
  }
  else {
    vec3 p = hit-s.pos;
    if       (p.x < -s.radius+EPS) return vec3(-1.0, 0.0, 0.0);
    else if (p.x >  s.radius-EPS) return vec3( 1.0, 0.0, 0.0);
    else if (p.y < -s.radius+EPS) return vec3(0.0, -1.0, 0.0);
    else if (p.y >  s.radius-EPS) return vec3(0.0,  1.0, 0.0);
    else if (p.z < -s.radius+EPS) return vec3(0.0, 0.0, -1.0);
    else return vec3(0.0, 0.0, 1.0);
  }
}

////////////////////////////////////////////////////////////////////////////////
// GLOBALS 
////////////////////////////////////////////////////////////////////////////////

varying vec2 vUv;

uniform vec3 uCamCenter;
uniform vec3 uCamPos;
uniform vec3 uCamUp;
uniform float uAspect;

const vec3 uRoomDim = vec3(5.0, 5.0, 5.0);
const vec3 uLightP = vec3(0.0, 4.9, 0.0);
const float uLightI = 1.0;

const float SPEC = 30.0;
const float REFL = 0.5;
const float Ka = 0.2;
const float Kt = 0.6;
const float Kr = 0.8;
float Ks, Kd;
const float Kx = 0.5;
const float Kx1 = 1.5;

const int SHAPE_NUM = 1;    // hardcoded constants for now for loops
Shape shapes[SHAPE_NUM];

////////////////////////////////////////////////////////////////////////////////
// INTERSECTIONS 
////////////////////////////////////////////////////////////////////////////////

bool intersectRoom(vec3 P, vec3 V,
  out vec3 pos, out vec3 normal, out vec3 color) {
  
  vec3 tMin = (-uRoomDim-P) / V;
  vec3 tMax = (uRoomDim-P) / V;
  vec3 t1 = min(tMin, tMax);
  vec3 t2 = max(tMin, tMax);
  float tNear = max(max(t1.x, t1.y), t1.z);
  float tFar = min(min(t2.x, t2.y), t2.z);
  
  if (tNear<tFar && tFar>0.0) {
    // take tFar, want back of box
    
    pos = P+tFar*V;
    
    if       (pos.x < -uRoomDim.x+EPS) { normal = vec3( 1.0, 0.0, 0.0); color = vec3(1.0, 1.0, 0.0); }
    else if (pos.x >  uRoomDim.x-EPS) { normal = vec3(-1.0, 0.0, 0.0); color = vec3(0.0, 0.0, 1.0); }
    else if (pos.y < -uRoomDim.y+EPS) {
      normal = vec3(0.0,  1.0, 0.0);
      if (fract(pos.x / 5.0) > 0.5 == fract(pos.z / 5.0) > 0.5) {
        color = vec3(0.5);
      }
      else {
        color = vec3(0.0);
      }
    }
    else if (pos.y >  uRoomDim.y-EPS) { normal = vec3(0.0, -1.0, 0.0); color = vec3(0.5); }
    else if (pos.z < -uRoomDim.z+EPS) { normal = vec3(0.0, 0.0,  1.0); color = vec3(0.5); }
    else { normal = vec3(0.0, 0.0, -1.0); color = vec3(0.5); }
    
    return true;
  }
  
  return false;
}

bool rayIntersect(vec3 P, vec3 V,
  out vec3 pos, out vec3 normal, out vec3 color) {
  
  float t_min = HUGE_VAL;
  
  float t;
  Shape s;
  bool hit = false;
  vec3 n, c;
  for (int i=0; i<SHAPE_NUM; i++) {
    if (intersect(shapes[i],P,V,t) && t<t_min) {
      t_min=t;
      hit = true;
      s = shapes[i];
    }
  }
  
  if (hit) {
    pos = P+V*t_min;
    normal = getNormal(s, pos);
    color = s.color;
    return true;
  }
  
  return intersectRoom(P,V,pos,normal,color);
}

bool rayIntersect(vec3 P, vec3 V,
  out vec3 pos, out vec3 normal, out vec3 color,
  out float kt, out float ks) {
  
  float t_min = HUGE_VAL;
  
  float t;
  Shape s;
  bool hit = false;
  vec3 n, c;
  for (int i=0; i<SHAPE_NUM; i++) {
    if (intersect(shapes[i],P,V,t) && t<t_min) {
      t_min=t;
      hit = true;
      s = shapes[i];
    }
  }
  
  if (hit) {
    pos = P+V*t_min;
    normal = getNormal(s, pos);
    color = s.color;
    kt = Kt;
    ks = 1.0;
    return true;
  }
  
  kt = 0.0;
  ks = 0.0;
  return intersectRoom(P,V,pos,normal,color);
}

////////////////////////////////////////////////////////////////////////////////
// RAY TRACE 
////////////////////////////////////////////////////////////////////////////////

vec3 computeLight(vec3 V, vec3 P, vec3 N, vec3 color) {
  vec3 L = normalize(uLightP-P);
  vec3 R = reflect(L, N);
  
  return
    color*(Ka + Kd*uLightI*dot(L, N)) +
    vec3(Ks*uLightI*pow(max(dot(R, V), 0.0), SPEC));
}

vec4 raytrace(vec3 P, vec3 V) {
  vec3 p1, norm, p2, col, c;
  float kt, ks;
  if (rayIntersect(P, V, p1, norm, c, kt, ks)) {
    col = computeLight(V, p1, norm, c)*(1.0-kt);
            
    vec3 norm2, c2;
    vec3 cm2 = (c + Kx) / Kx1;
    vec3 V2 = reflect(V, norm);
    float ks1; 
    if (rayIntersect(p1+EPS*V2, V2, p2, norm2, c2, kt, ks1)) {
      col += computeLight(V2, p2, norm2, c2) * cm2 * ks;
      cm2 *= (c2 + Kx) / Kx1;
      
      ks1 *= ks;
      vec3 p3;
      V2 = reflect(V2, norm2);
      if (rayIntersect(p2+EPS*V2, V2, p3, norm2, c2, kt, ks)) {
        col += computeLight(V2, p3, norm2, c2) * cm2 * ks1;
      }
    }
    
    vec3 norm1, c1;
    vec3 cm1 = (c + Kx) / Kx1;
    vec3 V1 = refract(V, norm, Kr);
    if (rayIntersect(p1+EPS*V1, V1, p2, norm1, c1, kt, ks)) {
      col += computeLight(V1, p2, norm1, c1) * cm1 * (1.0-kt);
      cm1 *= (c1 + Kx) / Kx1;
      
      vec3 p3;
      V1 = refract(V1, -norm1, Kr);
      if (rayIntersect(p2+EPS*V1, V1,p3, norm1, c1, kt, ks)) {
        col += computeLight(V1, p3, norm1, c1) * cm1 * (1.0-kt);
        
        vec3 norm3, c3;
        vec3 cm3 = (c1 + Kx) / Kx1;
        vec3 V3 = reflect(V1, norm1);
        float ks1; 
        if (rayIntersect(p3+EPS*V3, V3, p3, norm1, c1, kt, ks1)) {
          col += computeLight(V3, p3, norm1, c1) * cm3 * ks;
        }
      }
    }
  
    return vec4(col, 1.0);
  }
  else {
    return vec4(0.0, 0.0, 0.0, 1.0);
  }
}

////////////////////////////////////////////////////////////////////////////////
// MAIN 
////////////////////////////////////////////////////////////////////////////////

void initScene() {
  Shape s = Shape(true, vec3(0.0), 1.0, vec3(0.7, 0.0, 0.0));
  shapes[0] = s;
}

void main(void)
{
  Ks = (1.0-Ka)*REFL;
  Kd = (1.0-Ka)*(1.0-REFL);
  
  initScene();
  
  /* RAY TRACE */
  vec3 C = normalize(uCamCenter-uCamPos);
  vec3 A = normalize(cross(C,uCamUp));
  vec3 B = -1.0/uAspect*normalize(cross(A,C));
  
  // scale A and B by root3/3 : fov = 30 degrees
  vec3 P = uCamPos+C + (2.0*vUv.x-1.0)*ROOTTHREE*A + (2.0*vUv.y-1.0)*ROOTTHREE*B;
  vec3 R1 = normalize(P-uCamPos);
  
  gl_FragColor = raytrace(uCamPos, R1);
}