# 阅读与讲解路线

## 阅读顺序

1. `pmic_top.sv`：先明确数字控制边界，追踪 96 位 ADC 帧如何进入四条控制路径。
2. `fixed_pid.sv`：看 Q8.8、正负误差、积分限幅和条件抗积分饱和，再看锁存和三阶段计算。
3. `pwm_deadtime.sv`：手算 phase、duty、deadtime 对高低侧实际脉宽的影响。
4. `rail_sequencer.sv`、`rail_protection.sv`：分清正常关电顺序与故障全关，追踪 qualified、timeout 和 W1C。
5. `adc_mailbox.sv`、`reset_sync.sv`：说明为什么整帧数据保持到 ack，及共同复位丢弃 epoch 的规则。
6. `i2c_register_slave.sv`、`pmic_registers.sv`：追一段 repeated START 读；说明 shadow/active 与 telemetry snapshot 的区别。
7. `tb_pmic.sv`、`pid_reference.py`：亲自运行一种故障注入和一组位精确模型测试。

## 三个重点机制

### 配置原子性

主机逐字节更新 shadow，控制环仍读取原 active。RUN=0 且状态 OFF 后，commit 校验全部轨，再同一个主时钟边沿更新整个活动配置。运行中 commit 被拒绝，置 config_error，不更改活动参数也不停止现有运行。

PWM 有独立的帧边界锁存，控制环每次生成新 duty 后等待下一 PWM 周期生效。因此配置事务整体性与输出帧整体性是两个不同层次。

### 多位 CDC

源域保持整个 ADC payload，翻转 request 后停止改数据。目标域只同步 request，在数据已经稳定时一次读取 payload，再将 ack 同步回源域。source ready 表示可以发送下一帧。目标端还避免在 dst_valid 输出拍重复采样，保证 PID 消费窗口。

### 故障路径

ADC 检测 OV/UV/OC 经过三样本去抖；external trip 经过两级同步直接参与 PWM 门控；stale 在主时钟域计数。故障原因锁存，时序机关闭全部轨。清除要求 RUN=0 且轨已关闭，随后软件重新启动。

## 能据实讲的设计取舍

| 追问 | 本项目的具体实现 |
|---|---|
| 为什么用定点？ | 系数 Q8.8，误差/乘积/求和宽度明确，可逐样本比对并综合；ADC 码和 duty 码无需浮点。 |
| 积分饱和怎么处理？ | 积分自身限幅；输出越界且误差继续推向边界时冻结本次积分。 |
| 为什么 PID 分阶段？ | 乘法与 64 位累加分拍，锁存样本和参数；接受后第 3 拍完成。实际时序仍需要目标库验证。 |
| 死区在哪插入？ | 帧起点 high 延迟 deadtime；high 截止 duty 后 low 再延迟 deadtime；两者无重叠。 |
| duty 能热更新吗？ | 新 duty 只在下一帧边界锁存，不会截断当前脉冲。 |
| 上电欠压会误报吗？ | 轨未 qualified 时禁止 UV 去抖，由启动 timeout/stale 管理失败；qualified 后才检查 UV。 |
| 一路故障其他轨怎么办？ | 当前安全策略全关并锁存，不自动重试；避免依赖轨继续供电。 |
| I²C 是另一个时钟域吗？ | 引脚异步输入经过同步/滤波，状态机全部使用主时钟。真正的第二域为 ADC。 |
| 软件写一半寄存器怎么办？ | 部分 byte 只进入 shadow；未完成的字节被 START/STOP 丢弃；没有成功 commit 就不影响 active。 |
| 有多位读回不一致吗？ | 每次 read address 命中时冻结整帧遥测和状态，连读字节来自同一次快照。 |
| 控制效果如何？ | 已验证一阶整数行为模型的目标/负载阶跃，1200 样本位精确核对；真实功率级需要独立模拟/板级验证。 |

简历和面试应按实际参与程度描述，并能亲自复现源码、测试和结果。建议先修改一个真实功能，例如增加 IRQ 状态寄存器、ADC 不同采样周期或可编程故障去抖，补齐对应回归后再讲个人实现过程。
