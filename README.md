# CUDA Hello World:用 nvcc 编译与运行的完整步骤

配套源码:`helloworld.cu`(与本文件同目录)

## 0. 环境前提

| 项 | 本机情况 |
| --- | --- |
| nvcc | `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2\bin\nvcc.exe`(V13.2.78) |
| CUDA_PATH | `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2` |

关键点:**Windows 上的 nvcc 必须用 MSVC 的 `cl.exe` 作主机编译器**,不接受 MinGW 的 g++ 或 clang(`-ccbin` 在 Windows 上指的也是 cl.exe 所在目录)。本机装了 CUDA 13.2 但没装 Visual Studio,所以现在直接编译会失败:

```
> nvcc helloworld.cu -o helloworld.exe
nvcc fatal   : Cannot find compiler 'cl.exe' in PATH
```

所以先把第 1 步做完,后面的命令才有效。

## 1. 一次性准备:安装 MSVC 主机编译器

装 **Visual Studio 2022 生成工具**(Build Tools,免费,**不要**装完整版 IDE 也可以),安装时勾选工作负载:

> **使用 C++ 的桌面开发**(Desktop development with C++)——它包含 MSVC v143 编译器与 Windows SDK

命令行安装(需要**管理员**权限,会弹 UAC;下载约 2–5 GB):

```bat
winget install --id Microsoft.VisualStudio.2022.BuildTools ^
  --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

或者用官方安装器手动装:`https://visualstudio.microsoft.com/visual-cpp-build-tools/`

装完后**重新打开终端**(PATH 需要刷新),自检:

```bat
where cl
```

能打印出类似 `C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.xx.xxxxx\bin\Hostx64\x64\cl.exe` 就 OK。

## 2. 进入 x64 原生工具命令行

nvcc 需要 `cl.exe` 在 PATH 里,而且要用 **64 位**的。两种方式:

**方式 A(推荐)**:开始菜单搜索并打开

> **x64 Native Tools Command Prompt for VS 2022**

**方式 B**:在你已有的终端里手动导入环境

cmd:

```bat
call "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
```

PowerShell:

```powershell
cmd /c '"%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" && nvcc helloworld.cu -o helloworld.exe -arch=sm_75 && .\helloworld.exe'
```

> 注意:`vcvars64.bat` 是批处理脚本,在 PowerShell 里必须用 `cmd /c "..."` 包起来执行,直接调用不会把变量带进当前会话。

## 3. 编译

```bat
nvcc helloworld.cu -o helloworld.exe -arch=native
```

参数说明:

| 参数 | 作用 |
| --- | --- |
| `-o helloworld.exe` | 输出文件名(Windows 上建议显式写 `.exe`) |
| `-arch=native` | 按当前系统上的所有 `sm_*` 生成(本机即 sm_75),`-arch=all` / `-arch=all-major` 同族 |
| (省略 `-arch`) | 用工具链默认目标;可能只生成 PTX 需要 JIT,首次运行略慢 |

编译前可以先看看本机 CUDA 支持哪些架构(**不需要 cl.exe 就能跑**):

```bash
nvcc --list-gpu-arch
```

编译成功不会有任何输出,只是静静生成 `helloworld.exe`。

## 4. 运行

cmd:

```bat
helloworld.exe
```

PowerShell:

```powershell
.\helloworld.exe
```

## 5. 一步到位(编译 + 运行)

```bash
nvcc --run helloworld.cu -arch=native
```

`--run` 会编译到临时文件后立即执行;要传参给程序用 `--run-args`:

```bash
nvcc --run helloworld.cu --run-args a b c
```

## 6. 预期输出

```
Hello, World! from CPU
Hello, World! from GPU  (block 0, thread 0)
Hello, World! from GPU  (block 0, thread 1)
Hello, World! from GPU  (block 0, thread 2)
Hello, World! from GPU  (block 0, thread 3)
Hello, World! from GPU  (block 1, thread 0)
Hello, World! from GPU  (block 1, thread 1)
Hello, World! from GPU  (block 1, thread 2)
Hello, World! from GPU  (block 1, thread 3)
done.
```

共 1 行 CPU + 8 行 GPU(2 个 block × 4 个线程)+ 1 行 `done.`。

两点须知:

- **顺序不保证**。GPU 线程是并行执行的,8 行的先后顺序每次运行都可能不同;`from CPU` 一定在最前(在启动 kernel 之前就打印了)。
- **device 端 `printf` 是异步缓冲的**。只有遇到 `cudaDeviceSynchronize()`、`cudaMemcpy()` 这类同步点(或进程正常结束时)才会刷到终端。如果你把源码里的 `cudaDeviceSynchronize()` 删掉,很可能一行 GPU 输出都看不到。

## 7. 常用附加选项

```bat
:: 查看寄存器 / 共享内存 / 栈 用量(做性能调优时最常用)
nvcc helloworld.cu -o helloworld.exe -arch=sm_75 --ptxas-options=-v

:: 只生成 PTX 汇编,看编译器把代码变成了什么
nvcc -ptx helloworld.cu -o helloworld.ptx -arch=sm_75

:: 保留中间产物(.ptx/.cubin/.fatbin 等),便于排查
nvcc helloworld.cu -o helloworld.exe -arch=sm_75 -keep

:: 开启设备端调试信息,配合 compute-sanitizer / cuda-gdb 使用
nvcc helloworld.cu -o helloworld.exe -arch=sm_75 -G -g

:: 让主机编译器把警告开到最大
nvcc helloworld.cu -o helloworld.exe -arch=sm_75 -Xcompiler "/W4"

:: 检查越界访问、竞态条件、未初始化显存读
compute-sanitizer .\helloworld.exe
```

## 8. 故障排查

| 报错 / 现象 | 原因 | 处理 |
| --- | --- | --- |
| `nvcc fatal : Cannot find compiler 'cl.exe' in PATH` | 没装 MSVC,或没进 x64 Native Tools 命令行 | 做第 1、2 步 |
| `'nvcc' 不是内部或外部命令` | CUDA 的 `bin` 不在 PATH | 用完整路径调用,或把 `%CUDA_PATH%\bin` 加进 PATH |
| 程序正常退出,但**一行 GPU 输出都没有** | 漏了同步,device printf 缓冲没刷出 | 在 kernel 后加 `cudaDeviceSynchronize()` |
| `CUDA error: no kernel image is available for execution on the device` | 编译的目标架构和显卡不匹配 | 加 `-arch=sm_75` 或 `-arch=native` 重新编译 |
| `CUDA error: invalid device function` | 同上,架构不匹配 | 同上 |
| `unsupported gpu architecture 'compute_xx'` | CUDA 13.x 已不再支持 Maxwell / Pascal / Volta | 对老卡改用 12.x 及更早的 CUDA |
| 路径报错、找不到文件 | 路径里有空格却没加引号 | 用 `"F:\My Dir\helloworld.cu"` 形式 |

关于 CUDA 13 取消老架构支持的官方说明:[Navigating GPU Architecture Support(NVIDIA Technical Blog)](https://developer.nvidia.com/blog/navigating-gpu-architecture-support-a-guide-for-nvidia-cuda-developers/)

## 9. 换机器 / 换显卡时

- 只想在本机跑:**`-arch=native`** 最省事。
- 想编译一次、到处能跑:同时生成 SASS 和 PTX,例如
  `nvcc helloworld.cu -o helloworld.exe -gencode arch=compute_75,code=sm_75 -gencode arch=compute_75,code=compute_75`

## 附:Linux 上的对应步骤(参考)

```bash
nvcc helloworld.cu -o helloworld -arch=native
./helloworld
```

Linux 下 nvcc 用系统 gcc/g++ 作主机编译器,不需要额外装 MSVC——这也是本机 Windows 环境下最折腾的一点。
