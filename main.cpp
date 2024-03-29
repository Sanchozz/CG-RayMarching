//internal includes
#include "common.h"
#include "ShaderProgram.h"
#include "LiteMath.h"

//External dependencies
#define GLFW_DLL

#include <GLFW/glfw3.h>
#include <random>

using namespace LiteMath;

class Camera {
    float3 wFront;
    float3 wUp;
    float3 wRight;
    float3 wPos;
public:
    float3 pos;
    float3 front;
    float3 up;
    float3 right;
    GLfloat cameraXAngle;
    GLfloat cameraYAngle;
    GLfloat mouseSensitivity;
    Camera( float3 _pos = float3(0.0f, 0.0f, 3.5f), 
            float3 _front = float3(0.0f, 0.0f, -1.0f),
            float3 _up = float3(0.0f, 1.0f, 0.0f)) 
            : wFront(_front)
            , wUp(_up)
            , wRight(normalize(cross(_up, _front)))
            , wPos(_pos)
            , pos(_pos)
            , front(_front)
            , up(_up)
            , right(normalize(cross(_up, _front)))
            , cameraXAngle(-90.0f)
            , cameraYAngle(0.0f)
            , mouseSensitivity(0.1f) {
                updateVectors();
            }

    float4x4 GetViewMatrix() const {
        return lookAtTransposed(pos, pos + front, up);
    }

    void setInitPos() {
        front = wFront;
        right = wRight;
        up = wUp;
        pos = wPos;
        cameraXAngle = -90.0f;
        cameraYAngle = 0.0f;
        updateVectors();
    }

    void updateVectors() {
        float3 tmp;

        tmp.x = cos(DEG_TO_RAD * cameraXAngle) * cos(DEG_TO_RAD * cameraYAngle);
        tmp.y = sin(DEG_TO_RAD * cameraYAngle);
        tmp.z = sin(DEG_TO_RAD * cameraXAngle) * cos(DEG_TO_RAD * cameraYAngle);

        front = normalize(tmp);
        right = normalize(cross(front, wUp));
        up = normalize(cross(right, front));
    }

    void ProcessMouseMove(GLfloat deltaX, GLfloat deltaY, GLboolean limitAngle) {
        deltaX *= mouseSensitivity;
        deltaY *= mouseSensitivity;

        cameraXAngle += deltaX;
        cameraYAngle += deltaY;

        if (limitAngle) {
            if (cameraYAngle > 89.0f) {
                cameraYAngle = 89.0f;
            }
            if (cameraYAngle < -89.0f) {
                cameraYAngle = -89.0f;
            }
        }
        updateVectors();
    }

    void ProcessKeyboard(int dir, GLfloat deltaTime, GLfloat a) {
        GLfloat v = a * deltaTime;

        if (dir == 0) {
            pos += front * v;
        }
        if (dir == 1) {
            pos -= front * v;
        }
        if (dir == 2) {
            pos -= right * v;
        }
        if (dir == 3) {
            pos += right * v;
        }
        if (dir == 4) {
            pos += wUp * v;
        }
        if (dir == 5) {
            pos -= wUp * v;
        }
    }
};

static GLsizei WIDTH = 512, HEIGHT = 512; //размеры окна
static GLsizei FRAMEBUFFER_WIDTH = 512, FRAMEBUFFER_HEIGHT = 512;



Camera camera;
static GLfloat mx = 0, my = 0;
static bool keys[512];
static bool firstMouse = true;
static bool captureMouse = false;
static bool captured = false;
static int sceneIndex = 1;
static int fractalIter = 3;
static int fractalIterReleased = true;
static float angle = 0.0f;

GLfloat deltaTime = 0.0f;
GLfloat lastFrame = 0.0f;


void windowResize(GLFWwindow *window, int width, int height) {
    WIDTH = width;
    HEIGHT = height;
}

void framebufferResize(GLFWwindow *window, int width, int height) {
    FRAMEBUFFER_WIDTH = width;
    FRAMEBUFFER_HEIGHT = height;
}

static void mouseMove(GLFWwindow *window, double xpos, double ypos) {
    if (firstMouse) {
        mx = float(xpos);
        my = float(ypos);
        firstMouse = false;
    }

    GLfloat xoffset = float(xpos) - mx;
    GLfloat yoffset = my - float(ypos);  

    mx = float(xpos);
    my = float(ypos);
    
    if (captureMouse) {
        camera.ProcessMouseMove(xoffset, yoffset, true);
    }

}

static void mouseClick(GLFWwindow* window, int button, int action, int mods)
{
    if (button == GLFW_MOUSE_BUTTON_RIGHT && action == GLFW_RELEASE) {
        captureMouse = !captureMouse;
    }

    if (!captureMouse) {
        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
    } else {
        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        captured = true;
    }

}

static void keyboardPress(GLFWwindow* window, int key, int scancode, int action, int mode) {
    switch (key) {
        case GLFW_KEY_ESCAPE:
            if (action == GLFW_PRESS) {
			    glfwSetWindowShouldClose(window, GL_TRUE);
            }
            break;
        case GLFW_KEY_Z:
            if (action == GLFW_PRESS) {
                if (!keys[key]) {
                    keys[key] = true;
                    if (fractalIter > 0) {
                        fractalIter--;
                    }
                    
                } 
            } else if (action == GLFW_RELEASE) {
			    keys[key] = false;
            }
            break;
        case GLFW_KEY_X:
            if (action == GLFW_PRESS) {
                if (!keys[key]) {
                    keys[key] = true;
                    fractalIter++;
                } 
            } else if (action == GLFW_RELEASE) {
			    keys[key] = false;
            }
            break;
        case GLFW_KEY_0:
            if (action == GLFW_PRESS) {
                if (!keys[key]) {
                    keys[key] = true;
                    sceneIndex = 1;
                    camera.setInitPos();
                } 
            } else if (action == GLFW_RELEASE) {
			    keys[key] = false;
            }
            break;
        case GLFW_KEY_1:
            if (action == GLFW_PRESS) {
                if (!keys[key]) {
                    keys[key] = true;
                    sceneIndex = 1;
                    camera.setInitPos();
                } 
            } else if (action == GLFW_RELEASE) {
			    keys[key] = false;
            }
            break;
        case GLFW_KEY_2:
            if (action == GLFW_PRESS) {
                if (!keys[key]) {
                    keys[key] = true;
                    sceneIndex = 2;
                    fractalIter = 3;
                    camera.setInitPos();
                } 
            } else if (action == GLFW_RELEASE) {
			    keys[key] = false;
            }
            break;
        case GLFW_KEY_3:
            if (action == GLFW_PRESS) {
                if (!keys[key]) {
                    keys[key] = true;
                    sceneIndex = 3;
                    fractalIter = 9;
                    camera.setInitPos();
                } 
            } else if (action == GLFW_RELEASE) {
			    keys[key] = false;
            }
            break;
        default:
            if (action == GLFW_PRESS) {
			    keys[key] = true;
            } else if (action == GLFW_RELEASE) {
			    keys[key] = false;
            }
            break;
    }
}

static void cameraMove(Camera &camera, GLfloat deltaTime)
{
    GLfloat a = 0.5;
    if (keys[GLFW_KEY_LEFT_SHIFT]) {
        a = 2.0;
    }
    if (keys[GLFW_KEY_W]) {
        camera.ProcessKeyboard(0, deltaTime, a);
    }
    if (keys[GLFW_KEY_A]) {
        camera.ProcessKeyboard(2, deltaTime, a);
    }
    if (keys[GLFW_KEY_S]) {
        camera.ProcessKeyboard(1, deltaTime, a);
    }
    if (keys[GLFW_KEY_D]) {
        camera.ProcessKeyboard(3, deltaTime, a);
    }
    if (keys[GLFW_KEY_R]) {
        camera.ProcessKeyboard(4, deltaTime, a);
    }
    if (keys[GLFW_KEY_F]) {
        camera.ProcessKeyboard(5, deltaTime, a);
    }
}


int initGL() {
    int res = 0;
    //грузим функции opengl через glad
    if (!gladLoadGLLoader((GLADloadproc) glfwGetProcAddress)) {
        std::cout << "Failed to initialize OpenGL context" << std::endl;
        return -1;
    }

    std::cout << "Vendor: " << glGetString(GL_VENDOR) << std::endl;
    std::cout << "Renderer: " << glGetString(GL_RENDERER) << std::endl;
    std::cout << "Version: " << glGetString(GL_VERSION) << std::endl;
    std::cout << "GLSL: " << glGetString(GL_SHADING_LANGUAGE_VERSION) << std::endl;

    return 0;
}

int main(int argc, char **argv) {
    if (!glfwInit())
        return -1;

    //запрашиваем контекст opengl версии 3.3
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    GLFWwindow *window = glfwCreateWindow(WIDTH, HEIGHT, "OpenGL ray marching sample", nullptr, nullptr);
    if (window == nullptr) {
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }

    glfwGetFramebufferSize(window, &FRAMEBUFFER_WIDTH, &FRAMEBUFFER_HEIGHT);

    glfwSetCursorPosCallback(window, mouseMove);
    glfwSetMouseButtonCallback(window, mouseClick);
    glfwSetKeyCallback(window, keyboardPress); 
    glfwSetWindowSizeCallback(window, windowResize);
    glfwSetFramebufferSizeCallback(window, framebufferResize);

    glfwMakeContextCurrent(window);
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);

    if (initGL() != 0)
        return -1;

    //Reset any OpenGL errors which could be present for some reason
    GLenum gl_error = glGetError();
    while (gl_error != GL_NO_ERROR)
        gl_error = glGetError();

    //создание шейдерной программы из двух файлов с исходниками шейдеров
    //используется класс-обертка ShaderProgram
    std::unordered_map<GLenum, std::string> shaders;
    shaders[GL_VERTEX_SHADER] = "vertex.glsl";
    shaders[GL_FRAGMENT_SHADER] = "fragment.glsl";
    ShaderProgram program(shaders);
    GL_CHECK_ERRORS;

    glfwSwapInterval(1); // force 60 frames per second

    //Создаем и загружаем геометрию поверхности
    //
    GLuint g_vertexBufferObject;
    GLuint g_vertexArrayObject;
    {

        float quadPos[] =
        {
            -1.0f, 1.0f,    // v0 - top left corner
            -1.0f, -1.0f,    // v1 - bottom left corner
            1.0f, 1.0f,    // v2 - top right corner
            1.0f, -1.0f      // v3 - bottom right corner
        };

        g_vertexBufferObject = 0;
        GLuint vertexLocation = 0; // simple layout, assume have only positions at location = 0

        glGenBuffers(1, &g_vertexBufferObject);
        GL_CHECK_ERRORS;
        glBindBuffer(GL_ARRAY_BUFFER, g_vertexBufferObject);
        GL_CHECK_ERRORS;
        glBufferData(GL_ARRAY_BUFFER, 4 * 2 * sizeof(GLfloat), (GLfloat *) quadPos, GL_STATIC_DRAW);
        GL_CHECK_ERRORS;

        glGenVertexArrays(1, &g_vertexArrayObject);
        GL_CHECK_ERRORS;
        glBindVertexArray(g_vertexArrayObject);
        GL_CHECK_ERRORS;

        glBindBuffer(GL_ARRAY_BUFFER, g_vertexBufferObject);
        GL_CHECK_ERRORS;
        glEnableVertexAttribArray(vertexLocation);
        GL_CHECK_ERRORS;
        glVertexAttribPointer(vertexLocation, 2, GL_FLOAT, GL_FALSE, 0, 0);
        GL_CHECK_ERRORS;

        glBindVertexArray(0);
    }

    //цикл обработки сообщений и отрисовки сцены каждый кадр
    while (!glfwWindowShouldClose(window)) {
        GLfloat currentFrame = glfwGetTime();
		deltaTime = currentFrame - lastFrame;
		lastFrame = currentFrame;
        glfwPollEvents();
        cameraMove(camera, deltaTime);
        if (sceneIndex == 1) {
            angle += 0.02;
        }
        //очищаем экран каждый кадр
        glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
        GL_CHECK_ERRORS;
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GL_CHECK_ERRORS;

        program.StartUseShader();
        GL_CHECK_ERRORS;

        float4x4 rayMatrix = camera.GetViewMatrix();
        program.SetUniform("g_rayMatrix", rayMatrix);
        program.SetUniform("g_rayPos", camera.pos);
        if (sceneIndex == 1) {
            program.SetUniform("g_angle", angle);
        }
        if (sceneIndex != 1) {
            program.SetUniform("g_fractalIter", fractalIter);
        }
        program.SetUniform("g_sceneIndex", sceneIndex);
        program.SetUniform("g_screenWidth", WIDTH);
        program.SetUniform("g_screenHeight", HEIGHT);

        // очистка и заполнение экрана цветом
        //
        glViewport(0, 0, FRAMEBUFFER_WIDTH, FRAMEBUFFER_HEIGHT);
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

        // draw call
        //
        glBindVertexArray(g_vertexArrayObject);
        GL_CHECK_ERRORS;
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        GL_CHECK_ERRORS;  // The last parameter of glDrawArrays is equal to VS invocations

        program.StopUseShader();

        glfwSwapBuffers(window);
    }

    // очищаем vbo и vao перед закрытием программы
    //
    glDeleteVertexArrays(1, &g_vertexArrayObject);
    glDeleteBuffers(1, &g_vertexBufferObject);

    glfwTerminate();
    return 0;
}
