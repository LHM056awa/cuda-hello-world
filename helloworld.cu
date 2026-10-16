// helloworld.cu —— CUDA Hello World
//
// 编译 (Windows, 需已安装 MSVC 并进入 x64 Native Tools 命令行):
//     nvcc helloworld.cu -o helloworld.exe -arch=native

#include <cstdio>
#include <cstdlib>
#include <cuda_runtime.h>

#define CUDA_CHECK(expr)                                                                                               \
    do {                                                                                                               \
        cudaError_t err_ = (expr);                                                                                     \
        if (err_ != cudaSuccess) {                                                                                     \
            std::fprintf(stderr, "CUDA error: %s (%s:%d)\n", cudaGetErrorString(err_), __FILE__, __LINE__);            \
            std::exit(EXIT_FAILURE);                                                                                   \
        }                                                                                                              \
    } while (0)

// 在 GPU 上并行执行的核函数
__global__ void helloFromGPU() {
    // device 端 printf: 每个 GPU 线程各自打印一次
    printf("Hello, World! from GPU  (block %u, thread %u)\n", blockIdx.x, threadIdx.x);
}

int main() {
    std::printf("Hello, World! from CPU\n");

    // 启动 <<<gridDim, blockDim>>> = 2 个 block × 4 个线程
    helloFromGPU<<<2, 4>>>();

    CUDA_CHECK(cudaGetLastError());      // 捕获 kernel「启动」阶段的错误(如配置非法)
    CUDA_CHECK(cudaDeviceSynchronize()); // 等待 kernel 执行完, 并刷出 device printf 缓冲

    std::printf("done.\n");
    return 0;
}
