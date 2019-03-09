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

uniform float3 g_rayPos;

uniform float3 g_bBoxMin   = float3(-1, -1, -1);
uniform float3 g_bBoxMax   = float3(1, 1, 1);

uniform float4x4 g_rayMatrix;

uniform float4   g_bgColor = float4(0, 0, 1, 1);

// Максимальное количество шагов
#define MAX_MARCHING_STEPS 500
#define MIN_MARCHING_STEP 0.5
// Минимальная и максимальная дистанция
#define MIN_DIST 0.0
#define MAX_DIST 100.0
//
#define EPSILON  0.0001

float Sphere(vec3 pos, vec3 spos, float s) {
    return length(pos - spos) - s;
}

float udRoundBox( vec3 pos, vec3 b, float r )
{
  return length(max(abs(pos)-b, 0.0))-r;
}



float sceneSDF1(vec3 pos)
{
    vec3 spos = vec3(0.0, 0.0, 0.0);
    //return Sphere(pos, spos, 1.0);
    return udRoundBox(pos, vec3(.5, .5, 0.2), 0.3);
}

float sceneSDF2(vec3 pos)
{
    vec3 spos = vec3(1.0, 2.0, 3.0);
    
    return Sphere(pos, spos, 1.0);
}

float rayMarching(vec3 eye, vec3 rayDirection)
{
    float depth = MIN_DIST;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++)
    {
        float dist = sceneSDF1(eye + depth * rayDirection);
        //float dist2 = sceneSDF2(eye + depth * rayDirection);

        //float dist = min(dist1, dist2);
        if (dist < EPSILON) {
		    return depth;
        }
        depth += dist;
       
        if (depth >= MAX_DIST) {
            return MAX_DIST;
        }

    }
    return MAX_DIST;
}


float3 EyeRayDirection(float x, float y, float w, float h)
{
    float field_of_view = 3.141592654f / 2.0f;
    float3 ray_direction;

    ray_direction.x = x + 0.5f - (w / 2.0f);
    ray_direction.y = y + 0.5f - (h / 2.0f);
    ray_direction.z = -w / tan(field_of_view / 2.0f);

    return normalize(ray_direction);
}

vec3 estimateNormal(vec3 p)
{
    return normalize(vec3(
        sceneSDF1(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF1(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF1(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF1(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF1(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF1(vec3(p.x, p.y, p.z - EPSILON))
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

/**
 * Finds intersection with rectangular parallelepiped (box) whose axes are parallel to axes of the whole system (0x, 0y, 0z).
 *
 * @param ray_pos point - the origin of ray
 * @param ray_dir vector - the direction of ray
 * @param boxMin  point - box corner with all coordinates being minimum possible (and still be in box) (In 2D case this would be the lowest left corner)
 * @param boxMax  point - box corner with all coordinates being maximum possible (and still be in box) (In 2D case this would be the top right corner)
 * @param tmin    float - minimal distance to intersect the box (distance to first intersection)
 * @param tmax    float - maximum distance to intersect the box (distance to second intersection)
 * @return        bool  - true if there is an intersection with box
 */


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
    //ray_pos = (g_rayMatrix * float4(ray_pos, 1)).xyz;
    ray_dir = float3x3(g_rayMatrix)* ray_dir;

    float dist = rayMarching(ray_pos, ray_dir);
    
    if (dist > MAX_DIST - EPSILON) {
        fragColor = g_bgColor;
        return;
    } 

    vec3 p = ray_pos + dist * ray_dir;

    const vec3 K_a = vec3(0.0, 0.5, 0.0);
    const vec3 K_d = vec3(0.0, 1.0, 0.0); 
    const vec3 K_s = vec3(1.0, 1.0, 1.0);
    const float Shininess = 10.0;
    const vec3 ambientLight = 0.1 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * K_a;

    vec3 lightPos = vec3(4.0, 2.0, 4.0);
    vec3 lightIntensity = vec3(0.4, 0.4, 0.4);

    color += phongLight(K_d, K_s, Shininess, p, ray_pos, lightPos, lightIntensity);

    fragColor = vec4(color, 1);
}


