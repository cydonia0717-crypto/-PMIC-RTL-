# I²C 寄存器映射

地址为字节地址；16 位参数低字节在先。7 位 I²C 从机地址 `0x2D`，线上写地址字节为 `0x5A`，读地址字节为 `0x5B`。未实现位置读 0，写入忽略；普通 shadow 写会 ACK。

## 全局

| 地址 | 属性 | 内容 |
|---|---|---|
| 0x00 | RW | bit0 RUN；复位 0 |
| 0x01 | RW | bits3:0 轨 mask；复位 0xF；只在 RUN=0 且 OFF 时可写，否则 config_error |
| 0x02 | RO | bit7 config_error，bit4 snapshot_ready，bits2:0 snapshot_state |
| 0x03 | RO | bits3:0 snapshot_faults |
| 0x04 | W1C | bits3:0 清对应故障；只有 RUN=0 时产生清除请求 |
| 0x05 | RW | bits3:0 故障 IRQ 掩码，默认 0xF；config_error 独立产生 IRQ |
| 0x06 | RO | 芯片标识 0x50 |
| 0x07 | RO | 修订号 0x01 |
| 0x0C | WO | 写 bit0=1 请求原子提交全部 shadow |
| 0x10～0x13 | RO | 各轨 snapshot_causes 的 6 个原因位 |
| 0x14 | RO | snapshot_enabled bits3:0 |
| 0x18～0x27 | RO | 每轨 4 字节：V低、V高4位、I低、I高4位 |

状态编码：OFF=0，DELAY=1，WAIT_GOOD=2，ON=3，SHUTDOWN=4，FAULT=5。

## 每路 shadow 参数

轨 r 的起始地址为 `0x40 + 0x20*r`，r=0、1、2、3 对应 0x40、0x60、0x80、0xA0。参数读取返回 shadow 值；active 保留最后一次成功提交的整组配置。

| 偏移 | 字节数 | 默认值 | 内容 |
|---|---:|---:|---|
| +0x00 | 2 | 2,048 | target ADC 码 |
| +0x02 | 2 | 64 | Kp Q8.8（0.25） |
| +0x04 | 2 | 2 | Ki Q8.8（0.0078125） |
| +0x06 | 2 | 0 | Kd Q8.8 |
| +0x08 | 2 | 0 | duty_min |
| +0x0A | 2 | PWM_PERIOD-8 | duty_max |
| +0x0C | 1 | 4 | deadtime，主时钟拍数 |
| +0x0D | 1 | 2 | startup_delay，sequencer tick 数 |
| +0x0E | 2 | 1,600 | UV ADC 码 |
| +0x10 | 2 | 2,500 | OV ADC 码 |
| +0x12 | 2 | 3,000 | OC ADC 码 |
| +0x14 | 2 | 256 | startup_timeout，tick 数 |
| +0x16 | 1 | 0 | bit0 derivative_enable，0=PI，1=PID；其他位必须 0 |
| +0x17 | 1 | 64 | soft_step；0 为直接目标 |
| +0x18 | 2 | 128 | nominal target 的 power-good 容差 |
| +0x1A～0x1F | 6 | 0 | 保留；存储/读回，当前不影响行为 |

## 提交校验

所有四路都须满足：`UV < target < OV <= 4095`，OC<=4095，`duty_min <= duty_max <= PWM_PERIOD`，deadtime<duty_max，timeout>=3，tolerance 为 1～4095，三项系数非负，mode 只有 bit0 可置。

校验失败、RUN=1 或状态未到 OFF 时，config_error=1，全部 active 保持；不存在只更新一半轨的情况。shadow 编辑也不会影响当前 PWM。成功提交清 config_error。

## 主机访问示例

```text
写 rail0 target=2048：
 START 5A ACK 40 ACK 00 ACK 08 ACK STOP

停机提交并启动：
 write(00,00)      # 等状态 OFF
 write(0C,01)      # 提交
 read(02)         # 检查 config_error=0
 write(00,01)      # 启动

读芯片 ID 和 revision：
 START 5A ACK 06 ACK
 repeated START 5B ACK 50 master-ACK 01 master-NACK STOP

故障后恢复：
 write(00,00)
 write(04,0F)
 read(03)         # 确认故障已清除
 write(00,01)
```

这里用文本给出字节序列。实际软件还应根据电源依赖、目标 ADC 标定及状态读回决定何时启动。
