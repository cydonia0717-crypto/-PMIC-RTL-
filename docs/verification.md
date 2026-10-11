# 验证和结果边界

## 运行

```bash
make test
make lint
make cross
make synth
```

任何 $fatal、进程非零退出、缺失 PASS、比较失败或超时均使回归失败。每个仿真有 180 秒墙钟限制；系统 testbench 另有 2,500,000 拍的周期上限。CI 保存 JSON、trace、CSV 和日志。

## 验证矩阵

| 层次 | 场景 | 验证方法 |
|---|---|---|
| PID | 4,096 组持续历史，重置、正负误差、PI/PID、饱和、积分限幅 | 独立 Python 数学计算 duty/integral/error，RTL 逐样本核对；检查完成延迟 |
| PWM | 17 个 duty × 5 个 deadtime，85 组 | 统计整帧高低拍数；检查互斥、帧中更新保持、回绕更新、kill |
| 邮箱 | 2,000 完整帧，额外中断 epoch | 14ns/10ns 异步时钟，持续生产、周期反压、逐帧序列及 96 位签名、公共复位 |
| 保护 | OV/UV/OC/external/stale/equality 6 组 | 连续异常去抖、恢复计数清零、启动 UV 屏蔽、enabled 清除禁止 |
| 时序 | 5 组定向流程 | 每轨 DELAY 从零开始并逐 tick 检查；PG 遇坏 tick 清零、掩码跳轨、逆序关断、故障、deadline 与 qualification 同拍优先、选择性 W1C |
| 闭环 | 1,200 样本，目标阶跃、负载阶跃 | 统计实际 PWM high 拍数驱动一阶功率级；Python 分别重算每个 PID 和功率级样本 |
| 系统 | 正常掩码启动、UV、OV、OC、external、stale、timeout | 7 类 × 4 个时序随机种子；真实 I²C master 操作寄存器，异步 ADC 接口 |
| I²C/配置 | 所有系统用例中的公共前置流程 | 地址不匹配 NACK、重复 START、多字节 ACK/NACK、1 拍毛刺、未完成字节 STOP、reset 中止事务 |
| 数据整体性 | 所有系统用例中的公共前置流程 | shadow 部分更新不影响 active；坏配置整组拒绝；运行提交拒绝；读事务期间 ADC 变化但快照保持 |
| 电源时序 | 启停与故障恢复 | 完整 0→3/3→0 顺序、mask 跳轨、故障全关、RUN=1 清除无效、停机 W1C、显式重新启动 |
| 第二仿真器 | 7 类系统场景，seed=17 | Verilator 编译执行同一自检查 testbench |

PID 的 oracle 使用 Python 任意精度整数和独立公式，不复用 RTL 状态机；闭环功率级验证也用独立整数运算。系统场景由 testbench 的行为断言和输出 trace 检查，未对整个 PMIC 构造另一个完整周期精确模型。

## 功率级行为模型

每个 64 拍 PWM 帧统计高侧有效拍数 H。以 ADC 码表示输出：

`drive = floor(H * 4095 / 64) - load_offset`

`V_next = clamp(V + trunc_toward_zero((drive - V) / 8), 0, 4095)`

RTL 控制器的 target 在样本 400 从 2048 改为 2600，样本 800 的 load_offset 从 0 改为 400。控制器 KP=2、KI=1、KD=0，PWM duty 范围 0～60，deadtime=2。

最后三个 50 样本稳态窗口的最大绝对误差为 9、10、0 码，最终输出 2600。图像通过 `tools/plot_loop.py` 从实际仿真 CSV 生成；可用 `pip install matplotlib` 和 `make plot` 重新绘制。

这些数据只描述该离散行为模型，不代表真实 Buck/Boost 的纹波、效率、相位裕度或负载瞬态指标。

## Lint / 综合

主 RTL 使用 Verilator `--lint-only --Wall`，无警告。仿真器构建仅对 testbench 的整数宽度转换关闭 WIDTH 告警；生产 RTL 的独立 lint 仍为严格模式。

Yosys 对完整顶层执行 hierarchy/proc/opt/memory/check，映射存储器到通用寄存器逻辑并确认无 latch；PID 控制块另外执行完整通用门级映射。PID 映射结果为 6,247 个通用逻辑单元，其中 327 个触发器单元。单元数不是工艺面积，也不是整颗控制器的物理实现结果。

这里尚未执行正式 CDC/RDC 静态工具、形式验证、目标工艺/FPGA STA、SRAM 宏映射、P&R、I²C 电气时序或真实电源板测试。不会把 ASYNC_REG 属性或异步时钟仿真当作物理 CDC 签核。

## 本次工具

Icarus 12.0、Verilator 5.020、Yosys 0.33，执行日期 2026-10-11。最终机器可读结果见 `reports/regression.json`、`cross-simulator.json`、`closed-loop.json`、`synthesis.json`。

## 调试

```bash
# 单跑过流故障，保存 trace 和波形
vvp build/pmic.vvp +scenario=3 +seed=1 +trace=build/oc.trace +vcd

# 单跑一次第二仿真器
build/obj_verilator/pmic_verilator +scenario=6 +seed=17 +trace=build/timeout.trace
```

系统 trace 在使能变化时记录：主时钟计数（十进制）、状态（十进制）、enabled（十六进制）、faults（十六进制）、duties（十六进制）。它用于观察顺序/关断，详细算法结果来自独立的 PID 向量和闭环 CSV。
