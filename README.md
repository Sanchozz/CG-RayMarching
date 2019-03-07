# CMC MSU. Graphics course. Template for Ray Marching task

This is better template for task of Ray Marching for "Computer Graphics" course in CMC MSU 2019.

## Requirements

You need C++ compiler, CMake, make, OpenGL 3.3+ and GLFW3 library

To install everything, **except GLFW3** you can run this

`sudo apt install mesa-utils xorg-dev libglu1-mesa-dev cmake make build-essential`

If you are **NOT** using NuGet, MacPorts and Arch Linux, then
to install GLFW3, you can download, unzip, compile it on your own computer and install (This is what is said on https://www.glfw.org/download.html):
```
sudo apt install unzip cmake make && \
wget "https://github.com/glfw/glfw/releases/download/3.2.1/glfw-3.2.1.zip" && \
unzip glfw-3.2.1.zip && \
cd glfw-3.2.1 && \
sudo cmake -G "Unix Makefiles" && \
sudo make && \
sudo make install && \
cd .. && \
sudo rm -f glfw-3.2.1.zip && \
sudo rm -rf glfw-3.2.1
```
If you are **USING** NuGet, MacPorts and Arch Linux, then to install GLFW3 you can use:

`sudo <your package manager> install libglfw3`

## Installation and Run

0. Clone the repository and go to folder where it was cloned.
`git clone https://github.com/CrafterKolyan/cmc-msu-graphics-template-raymarching.git && cd cmc-msu-graphics-template-raymarching`
1. Create build folder and go to it. `mkdir build && cd build`
2. `cmake ..`
3. `make`
4. `./main`

If any error occured, please read the "Requirements" section.

## Enhancements done to the standard template
v.2
1. Fix Mac Retina Display 1/4 bug

v.1
1. No compilation error on MAC OS X
2. Shaders are now copied on build and also are thought to be source files
3. All files are reformated (4 space identation)
4. Function `EyeRayDir` renamed to `EyeRayDirection`
5. Function `RayBoxIntersection` now has documentation
6. Variable `fov` renamed to `field_of_view`
7. Add this `README.md`


## Known problems
If you are using Mac and try to use Parallels or Virtual Box (in some cases) with Ubuntu, then the latest version of OpenGL you can obtain is 2.1.
(Info from 04.03.2019)

**Use VMWare Workstation instead** or you can try to use Virtual Box to see if it works there.

Extra links:
1. Parallels support of OpenGL 3.2 thread https://forum.parallels.com/threads/opengl-3-2-support.336169/
2. Some StackOverflow question https://stackoverflow.com/questions/27566569/is-there-a-vm-that-i-can-do-opengl-3-with-virtualbox-and-vmware-dont