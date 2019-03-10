#version 440

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

uniform vec4 g_bgColor = float4(0, 1, 1, 1);

uniform int g_sceneIndex;

int sceneIndex = g_sceneIndex;
// Максимальное количество шагов
#define MAX_MARCHING_STEPS 500
#define MIN_MARCHING_STEP 0.5
// Минимальная и максимальная дистанция
#define MIN_DIST 0.0
#define MAX_DIST 100.0
//
#define EPSILON  0.000002

struct Object {
    int id;
    float dist;
  /*vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    float shininess;
    bool is_reflect;
    bool is_refract; */
};

struct Material {
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    float shininess;
};

float Sphere(vec3 pos, vec3 spos, float s) {
    return length(pos - spos) - s;
}

float udRoundBox( vec3 pos, vec3 b, float r )
{
    float dist = length(max(abs(pos)-b, 0.0))-r;
    if (dist < 0) {
        return -dist;
    }
    return dist;
}

float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return length(max(d,0.0))
            + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
}

float sdCross(vec3 pos) {
    float d = sdBox(pos, vec3(1.0));
    float s = 1.0;
    for (int m = 0; m < 4; m++) {
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



Object sceneSDF1(vec3 pos)
{
    Object objs[2];

    objs[0].id = 1;
    objs[0].dist = Sphere(pos, vec3(0.0, 1.0, 0.0), 1);
  /*objs[0].ambient = vec3(0.1745, 0.01175, 0.01175);
    objs[0].diffuse = vec3(0.61424, 0.04136, 0.04136);
    objs[0].specular = vec3(0.727811, 0.626959, 0.626959);
    objs[0].shininess = 2.6;
    objs[0].is_reflect = false;
    objs[0].is_refract = false;*/

    objs[1].id = 2;
    objs[1].dist = -sdBox(pos, vec3(6, 6, 6));
  /*objs[1].ambient = vec3(0.7, 0.7, 0.7);
    objs[1].diffuse = vec3(0.55, 0.55, 0.55);
    objs[1].specular = vec3(0.7, 0.7, 0.7);
    objs[1].shininess = 10.0;
    objs[1].is_reflect = false;
    objs[1].is_refract = false;*/

    float min_dist = 1000.0f;
    int nearest_i;
    for (int i = 0; i < 2; i++) {
        if (objs[i].dist < min_dist) {
            nearest_i = i;
            min_dist = objs[i].dist;
        }
    }

    //return Sphere(pos, spos, 1.0);
    return objs[nearest_i];
}

Object sceneSDF2(vec3 pos)
{
    Object objs[1];
    objs[0].id = 1;
    objs[0].dist = sdCross(pos);

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
    cur_obj.dist = MAX_DIST;
    return cur_obj;
}


float3 EyeRayDirection(float x, float y, float w, float h)
{
    float field_of_view = 3.141592654f / 2.0f;
    vec3 ray_direction;

    ray_direction.x = x + 0.5f - (w / 2.0f);
    ray_direction.y = y + 0.5f - (h / 2.0f);
    ray_direction.z = -w / tan(field_of_view / 2.0f);

    return normalize(ray_direction);
}

vec3 estimateNormal(vec3 p)
{
    return normalize(vec3(
        sceneSDF(sceneIndex, vec3(p.x + EPSILON, p.y, p.z)).dist - sceneSDF(sceneIndex, vec3(p.x - EPSILON, p.y, p.z)).dist,
        sceneSDF(sceneIndex, vec3(p.x, p.y + EPSILON, p.z)).dist - sceneSDF(sceneIndex, vec3(p.x, p.y - EPSILON, p.z)).dist,
        sceneSDF(sceneIndex, vec3(p.x, p.y, p.z  + EPSILON)).dist - sceneSDF(sceneIndex, vec3(p.x, p.y, p.z - EPSILON)).dist
    ));
}

vec3 phongLight(vec3 k_d, vec3 k_s, float shininess, vec3 p, vec3 eye, vec3 lightPos, vec3 lightIntensity)
{
    vec3 N = estimateNormal(p);
    vec3 L = normalize(lightPos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));

    float dotLN = dot(L, N);
    float dotRV = dot(R, V);

    if (dotLN < 0.0) {
        // С этой точки поверхности не видно света
        return vec3(0.0, 0.0, 0.0);
    }

    if (dotRV < 0.0) {
        // Отражение в противоположном направление от зрителя
        // используем  дифузный компонент
        return lightIntensity * (k_d * dotLN);
    }

    //
    return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, shininess));
}

float shadow(vec3 pos, vec3 dir, float mint, float maxt, int id) {
    for (float t = mint; t < maxt;) {
        Object obj = sceneSDF1(pos - dir * t);
        float h = obj.dist;
        if (id == obj.id) {
            h = 0.1;
        }
        if (h < EPSILON) {
            return 0.0;
        }
        t += abs(h);
    }
    return 1.0;

    /*pos = pos + dir * mint;
    float dist = sceneSDF1(pos).dist;
    float t = dist;

    float shadowFactor = 1.0;

    for (int i=0; i < 500; i++) {
        dist = sceneSDF1(pos + dir * t).dist;
        if (dist < EPSILON) {
            return 0.0;
        }

        shadowFactor = min(shadowFactor, (8.0) * dist / float(i));
        t += dist;
    }

    shadowFactor = clamp(shadowFactor, 0.0, 1.0);
    return shadowFactor;*/
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

    vec3 K_a;
    vec3 K_d;
    vec3 K_s;
    float Shininess;

    switch (obj.id) {
        case 1:
            K_a = vec3(0.1745, 0.01175, 0.01175);
            K_d = vec3(0.61424, 0.04136, 0.04136); 
            K_s = vec3(0.727811, 0.626959, 0.626959);
            Shininess = 2.6;
            break;
        case 2:
            K_a = vec3(0.1, 0.1, 0.1);
            K_d = vec3(0.55, 0.55, 0.55);
            K_s = vec3(0.2, 0.2, 0.2);
            Shininess = 13.0;
            break;
        default: 
            K_a = vec3(0.1745, 0.01175, 0.01175);
            K_d = vec3(0.61424, 0.04136, 0.04136); 
            K_s = vec3(0.727811, 0.626959, 0.626959);
            Shininess = 2.6;
            break;
    };
    /*const vec3 K_a = vec3(0.7, 0.7, 0.7);
    const vec3 K_d = vec3(0.55, 0.55, 0.55); 
    const vec3 K_s = vec3(0.7, 0.7, 0.7);
    const float Shininess = 30.0;*/
    vec3 lights[2];
    vec3 lightIntensity = vec3(0.5, 0.5, 0.5);
    const vec3 ambientLight = 0.5 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * K_a;
    lights[0] = vec3(2.0, 0, 0);
    lights[1] = vec3(0.0, 0.0, 2.0);
    //lights[2] = vec3(5.9, 5.9, -5.9);
    //lights[3] = vec3(-5.9, 5.9, -5.9);

    for (int i = 0; i < 2; i++) {
        vec3 diff = normalize(-vec3(lights[i] - p));
        color += phongLight(K_d, K_s, Shininess, p, ray_pos, lights[i], lightIntensity);
    }


    //vec3 lightPos = vec3(0.0, 0.0, 0.0);
    fragColor = vec4(color, 1.0);
}


