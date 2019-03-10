#version 330

#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float4x4 mat4
#define float3x3 mat3

in float2 fragmentTexCoord;

layout(location = 0) out vec4 fragColor;

uniform int g_screenWidth;
uniform int g_screenHeight;

uniform vec3 g_rayPos;

uniform vec3 g_bBoxMin   = float3(-1, -1, -1);
uniform vec3 g_bBoxMax   = float3(1, 1, 1);

uniform mat4 g_rayMatrix;

uniform vec4 g_bgColor = float4(0, 0, 1, 1);

uniform int g_sceneIndex;
uniform float g_angle;
uniform int g_fractalIter;

int sceneIndex = g_sceneIndex;
// Максимальное количество шагов
#define MAX_MARCHING_STEPS 150
#define MIN_MARCHING_STEP 0.5
// Минимальная и максимальная дистанция
#define MIN_DIST 0.0
#define MAX_DIST 100.0
//
#define EPSILON  0.00001

struct Object {
    int id;
    float dist;
};

mat3 rX(float ang){
    float c = cos(ang);
    float s = sin(ang);
    return mat3(1,0,0,
                0,c,-s,
                0,s,c);
}
mat3 rY(float ang){
    float c = cos(ang);
    float s = sin(ang);
    return mat3(c,0,s,
                0,1,0,
                -s,0,c);
}
mat3 rZ(float ang){
    float c = cos(ang);
    float s = sin(ang);
    return mat3(c,-s,0,
                s,c,0,
                0,0,1);
}

float Sphere(vec3 p, vec3 sp, float s) {
    return length(p - sp) - s;
}

float udRoundBox(vec3 p, vec3 b, float r)
{
    float dist = length(max(abs(p)-b, 0.0))-r;
    return dist;
}

float sdCylinder(vec3 p, vec3 c)
{
    return length(p.xz - c.xy) - c.z;
}

float sdBox(vec3 p, vec3 b)
{
    vec3 d = abs(p) - b;
    return length(max(d,0.0))
            + min(max(d.x,max(d.y,d.z)),0.0); 
}

float sdTorus(vec3 pos, vec2 t)
{
    vec2 q = vec2(length(pos.xz) - t.x, pos.y);
    return length(q) - t.y;
}

float sdOctahedron(vec3 p, float s)
{
    p = abs(p);
    float m = p.x+p.y+p.z-s;
    vec3 q;
         if( 3.0*p.x < m ) q = p.xyz;
    else if( 3.0*p.y < m ) q = p.yzx;
    else if( 3.0*p.z < m ) q = p.zxy;
    else return m*0.57735027;
    
    float k = clamp(0.5*(q.z-q.y+s),0.0,s); 
    return length(vec3(q.x,q.y-s+k,q.z-k)); 
}

float sdMenger(vec3 pos) {
    float d = sdBox(pos, vec3(1.0));
    float s = 1.0;
    for (int m = 0; m < g_fractalIter; m++) {
        vec3 a = mod(pos * s, 2.0) - 1.0;
        s *= 3.0;
        vec3 r = abs(1.0 - 3.0 * abs(a));

        float da = max(r.x, r.y);
        float db = max(r.y, r.z);
        float dc = max(r.z, r.x);
        float c = (min(da, min(db, dc)) - 1.0) / s;

        d = max(d, c);
    }
    
    return d;
}

float sdSierpinski(vec3 z)
{
    const float scale = 2.0;
    vec3 a1 = vec3(0.0,   1.0,  0.0);
    vec3 a2 = vec3(0.0,  -0.5,  1.5470);
    vec3 a3 = vec3(1.0,  -0.5, -0.57735);
    vec3 a4 = vec3(-1.0, -0.5, -0.57735);
    vec3 c;
    float dist, d;
    int i = 0;
    for(int n=0; n < g_fractalIter; n++) {
        c = a1; dist = length(z-a1);
        d = length(z-a2); if (d < dist) { c = a2; dist=d; }
        d = length(z-a3); if (d < dist) { c = a3; dist=d; }
        d = length(z-a4); if (d < dist) { c = a4; dist=d; }
        z = scale * z - c * (scale-1.0);
        i++;
    }

    return (length(z)-2.0) * pow(scale, float(-i));
}




Object sceneSDF1(vec3 pos)
{
    Object objs[7];

    objs[0].id = 1;
    objs[0].dist = Sphere(pos, vec3(0.0, 0.0, 0.0), 1);

    objs[1].id = 2;
    objs[1].dist = -sdBox(pos, vec3(7, 7, 7));

    objs[2].id = 3;
    objs[2].dist = Sphere(pos, vec3(3.0, 3.0, 3.0), 0.25);

    objs[3].dist = 100000.0;

    objs[4].id = 5;
    objs[4].dist = sdTorus(rZ(g_angle) * (pos - vec3(3.0, 3.0, 3.0)), vec2(0.7, 0.1));

    objs[5].id = 6;
    objs[5].dist = sdOctahedron(rY(g_angle) * (pos - vec3(0.0, -5.0, 0.0)) , 1.0f);

    objs[6].id = 7;
    objs[6].dist = sdCylinder((pos - vec3(-4.0, -4.0, -4.0)) , vec3(0.5, 0.5, 0.5));

    float min_dist = objs[0].dist;
    int nearest_i = 0;
    for (int i = 1; i < 6; i++) {
        if (objs[i].dist < min_dist) {
            nearest_i = i;
            min_dist = objs[i].dist;
        }
    }

    return objs[nearest_i];
}

Object sceneSDF2(vec3 pos)
{
    Object objs[1];
    objs[0].id = 1;
    objs[0].dist = sdMenger(pos);

    float min_dist = 1000.0f;
    int nearest_i;
    for (int i = 0; i < 1; i++) {
        if (objs[i].dist < min_dist) {
            nearest_i = i;
            min_dist = objs[i].dist;
        }
    }
    
    return objs[nearest_i];
}

Object sceneSDF3(vec3 pos)
{
    Object objs[1];
    objs[0].id = 1;
    objs[0].dist = sdSierpinski(rY(1.047) * pos);

    float min_dist = 1000.0f;
    int nearest_i;
    for (int i = 0; i < 1; i++) {
        if (objs[i].dist < min_dist) {
            nearest_i = i;
            min_dist = objs[i].dist;
        }
    }
    
    return objs[nearest_i];
}

Object sceneSDF(int index, vec3 pos) {
    if (index == 1) {
        return sceneSDF1(pos);
    } else if (index == 2) {
        return sceneSDF2(pos);
    } else if (index == 3) {
        return sceneSDF3(pos);
    }
    return sceneSDF1(pos);
}

Object rayMarching(vec3 eye, vec3 rayDirection)
{
    float depth = MIN_DIST;
    Object cur_obj;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++)
    {
        cur_obj = sceneSDF(sceneIndex, eye + depth * rayDirection);

        if (cur_obj.dist < EPSILON) {
            cur_obj.dist = depth;
		    return cur_obj;
        }
        depth += cur_obj.dist;
       
        if (depth >= MAX_DIST) {
            cur_obj.dist = MAX_DIST;
            return cur_obj;
        }

    }
    //cur_obj.dist = MAX_DIST;
    return cur_obj;
}


float3 EyeRayDirection(float x, float y, float w, float h)
{
    float field_of_view = 3.141592654f / 2.0f;
    vec3 ray_d;

    ray_d.x = x + 0.5f - (w / 2.0f);
    ray_d.y = y + 0.5f - (h / 2.0f);
    ray_d.z = -w / tan(field_of_view / 2.0f);

    return normalize(ray_d);
}

vec3 estimateNormal(vec3 p)
{
    return normalize(vec3(
        sceneSDF(sceneIndex, vec3(p.x + EPSILON, p.y, p.z)).dist - sceneSDF(sceneIndex, vec3(p.x - EPSILON, p.y, p.z)).dist,
        sceneSDF(sceneIndex, vec3(p.x, p.y + EPSILON, p.z)).dist - sceneSDF(sceneIndex, vec3(p.x, p.y - EPSILON, p.z)).dist,
        sceneSDF(sceneIndex, vec3(p.x, p.y, p.z  + EPSILON)).dist - sceneSDF(sceneIndex, vec3(p.x, p.y, p.z - EPSILON)).dist
    ));
}

vec3 phongLight(vec3 k_d, vec3 k_s, float shininess, vec3 p, vec3 eye, vec3 lightPos, vec3 lightint)
{
    vec3 N = estimateNormal(p);
    vec3 L = normalize(lightPos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));

    float dotLN = dot(L, N);
    float dotRV = dot(R, V);

    if (dotLN < 0.0) {
        return vec3(0.0, 0.0, 0.0);
    }

    if (dotRV < 0.0) {
        return lightint * (k_d * dotLN);
    }
    return lightint * (k_d * dotLN + k_s * pow(dotRV, shininess));
}

float shadow(vec3 pos, vec3 dir, float mint, float maxt) {
    for (float t = mint; t < maxt;) {
        Object obj = sceneSDF1(pos - dir * t);
        float h = obj.dist;
        if (h < EPSILON) {
            return 0.0;
        }
        t += h;
    }
    return 1.0;
}

void main(void)
{

    float w = float(g_screenWidth);
    float h = float(g_screenHeight);

    // get curr pixelcoordinates
    //
    float x = fragmentTexCoord.x * w;
    float y = fragmentTexCoord.y * h;

    // generate initial ray
    //
    float3 ray_pos = g_rayPos;
    float3 ray_dir = EyeRayDirection(x, y, w, h);

    // transorm ray with matrix
    //
    ray_dir = ray_dir * float3x3(g_rayMatrix);

    Object obj = rayMarching(ray_pos, ray_dir);
    
    if (obj.dist > MAX_DIST - EPSILON) {
        fragColor = g_bgColor;
        return;
    } 

    vec3 p = ray_pos + obj.dist * ray_dir;

    vec3 lights[3];
    const vec3 lightint = vec3(0.6, 0.6, 0.6);
    vec3 color;
    const vec3 ambientLight = 0.5 * vec3(1.0, 1.0, 1.0);
    if (sceneIndex == 1) {
        //vec3 color = ambientLight * K_a;
        color = vec3(0.0, 0.0, 0.0);
        lights[0] = vec3(4.0, 0, 0);
        lights[1] = vec3(0.0, 0.0, 4.0);


        float3 mir = float3(0.0, 0.0, 0.0);
        float mir_k = 1.0;
        if (obj.id == 1) {
            const vec3 K_a = vec3(0.6745, 0.61175, 0.61175);
            const vec3 K_d = vec3(0.0, 0.0, 0.0); 
            const vec3 K_s = vec3(0.9, 0.9, 0.9);
            const float Shininess = 30;
            for (int i = 0; i < 2; i++) {
                vec3 diff = normalize(-vec3(lights[i] - p));
                mir += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightint);
            }
            vec3 ref = reflect(normalize(ray_dir), -estimateNormal(p));
            obj = rayMarching(p + ref * 0.1, ref);
            p = p + ref * obj.dist;
            
            mir_k = .9;
        }


        if (obj.id == 2) {
            const vec3 K_a = vec3(0.1, 0.1, 0.1);
            const vec3 K_d = vec3(0.55, 0.55, 0.55);
            const vec3 K_s = vec3(0.2, 0.2, 0.2);
            const float Shininess = 4.0;
            for (int i = 0; i < 2; i++) {
                vec3 diff = normalize(-vec3(lights[i] - p));
                color += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightint) * shadow(p, diff, 0.01, length(lights[i]-p -0.01));
            }
            color += mir+mir_k*(K_d*.2 + color*.1);
        } else if (obj.id == 3) { //ruby
            const vec3 K_a = vec3(0.1745, 0.01175, 0.01175);
            const vec3 K_d = vec3(0.61424, 0.04136, 0.04136); 
            const vec3 K_s = vec3(0.727811, 0.626959, 0.626959);
            const float Shininess = 30;
            for (int i = 0; i < 2; i++) {
                vec3 diff = normalize(-vec3(lights[i] - p));
                color += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightint) * shadow(p, diff, 0.01, length(lights[i]-p)-0.01);
            }
            color += mir+mir_k*(K_d*.2 + color*.8);
        } else if (obj.id == 5) { //gold
            const vec3 K_a = vec3(0.19125, 0.0735, 0.0225);
            const vec3 K_d = vec3(0.7038, 0.27048, 0.0828); 
            const vec3 K_s = vec3(0.256777, 0.137622, 0.086014);
            const float Shininess = 3;
            for (int i = 0; i < 2; i++) {
                vec3 diff = normalize(-vec3(lights[i] - p));
                color += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightint) * shadow(p, diff, 0.01, length(lights[i]-p)-0.01);
            }
            color += mir+mir_k*(K_d*.2 + color*.8);
        } else if (obj.id == 6) { //sin cos color
            const vec3 K_a = vec3(0.1745, 0.01175, 0.01175);
            vec3 K_d = vec3(abs(cos(g_angle * 0.5)) * 1.0, abs(sin(4 * g_angle * 0.5)) * 1.0, abs(sin(g_angle * 0.5) * cos(g_angle * 0.5)) * 1.0);
            const vec3 K_s = vec3(0.727811, 0.626959, 0.626959);
            const float Shininess = 30;
            for (int i = 0; i < 2; i++) {
                vec3 diff = normalize(-vec3(lights[i] - p));
                color += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightint) * shadow(p, diff, 0.01, length(lights[i]-p)-0.01);
            }
            color += mir+mir_k*(K_d*.2 + color*.1);
        }
    } else if (sceneIndex == 2) { //copper
        lights[0] = vec3(-8.0, 4, 0);
        lights[1] = vec3(0.0, -2.0, 4.0);
        lights[2] = vec3(-6.0, 0.0, 4.0);
        const vec3 K_a = vec3(0.24725, 0.1995, 0.0745);
        const vec3 K_d = vec3(0.75164, 0.60648, 0.22648); 
        const vec3 K_s = vec3(0.628281, 0.555802, 0.366065);
        const float Shininess = 4;
        color = ambientLight * K_a;
       
        for (int i = 0; i < 3; i++) {
            vec3 diff = normalize(-vec3(lights[i] - p));
            color += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightint) * shadow(p, diff, 0.01, length(lights[i]-p -0.01));
        }
    } else if (sceneIndex == 3) { //copper
        lights[0] = vec3(-8.0, 4, 0);
        lights[1] = vec3(0.0, -2.0, 4.0);
        lights[2] = vec3(-6.0, 0.0, 4.0);
        const vec3 K_a = vec3(0.0, 0.05, 0.0);
        const vec3 K_d = vec3(0.4, 0.5, 0.4); 
        const vec3 K_s = vec3(0.04, 0.7, 0.05);
        const float Shininess = 4;
        color = ambientLight * K_a;
       
        for (int i = 0; i < 3; i++) {
            vec3 diff = normalize(-vec3(lights[i] - p));
            color += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightint) * shadow(p, diff, 0.01, length(lights[i]-p -0.01));
        }
    }

    fragColor = vec4(color, 1.0);
}


