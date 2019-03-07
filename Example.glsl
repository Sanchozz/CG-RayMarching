// Round Box
float udRoundBox( vec3 pos, vec3 b, float r )
{
  return length(max(abs(pos)-b, 0.0))-r;
}

float sceneSDF(vec3 pos)
{
    // Тут может быть много объектов
    // И даже их комбинации (пересечение, объединение и разность)
    return udRoundBox(pos, vec3(.5, .5, 0.2), 0.3);
}

// Максимальное количество шагов
#define MAX_MARCHING_STEPS 250
// Минимальная и максимальная дистанция
#define MIN_DIST 0.0
#define MAX_DIST 100.0
//
#define EPSILON  0.0001

// eye - позиция наблюдателя
// rayDirection - направление луча
float rayMarching(vec3 eye, vec3 rayDirection)
{
    float depth = MIN_DIST;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++)
    {
        // Ориентированная функция расстояния, нашей сцены
        float dist = sceneSDF(eye + depth * rayDirection);
        // Мы достигли поверхности
        if (dist < EPSILON)
		return depth;
        // Продвигаемся дальше по лучу
        depth += dist;
        // Луч не столкнулся с поверхностью
        if (depth >= MAX_DIST)
            return MAX_DIST;

    }
    return MAX_DIST;
}

// Направление луча
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord)
{
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

// Оцениваем нормали
vec3 estimateNormal(vec3 p)
{
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}


// Освещение по фонгу
// подробности https://en.wikipedia.org/wiki/Phong_reflection_model#Description
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

// Матрица вида
mat4 viewMatrix(vec3 eye, vec3 center, vec3 up)
{
    // Based on gluLookAt man page
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(-f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	    
    vec3 viewDir = rayDirection(45.0, iResolution.xy, fragCoord.xy);
    vec3 eye = vec3(8.0, 5.0, 7.0);
    // Переходим к Мировым координатам
    mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0));
    // Вычисляем дистанцию
    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
    // Запускаем наш луч
    float dist = rayMarching(eye, worldDir);

    if (dist > MAX_DIST - EPSILON)
        discard; //  Не рисуем

    // Самая близкая точка вдоль луча
    vec3 p = eye + dist * worldDir;

    // Константы для освещения
    const vec3 K_a = vec3(0.2, 0.2, 0.2); // Ambient color
    const vec3 K_d = vec3(1.0, 0.0, 0.0); // Diffuse color
    const vec3 K_s = vec3(1.0, 1.0, 1.0); // Specular color
    const float Shininess = 10.0; //
    const vec3 ambientLight = 0.5 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * K_a;
    // источник света
    vec3 lightPos = vec3(4.0 * sin(iTime),
                          2.0,
                          4.0 * cos(iTime));
    vec3 lightIntensity = vec3(0.4, 0.4, 0.4);
    color += phongLight(K_d, K_s, Shininess, p, eye, lightPos, lightIntensity);

    // Рисуем красным
    fragColor = vec4(color, 1.0);
}