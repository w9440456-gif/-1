import numpy as np
import statsmodels.stats.api as sms

# 实验组treatment：看到新的落地页面
# 对照组control：看到旧的落地页面
# convert 1:转化成功（即在该落地页购买了） 0:没有转化（没有在该落地页购买）


#  计算效应大小（）   # proportion_effectsize；比例效应大小
effect_size = sms.proportion_effectsize(0.13, 0.15)
print(effect_size)


#  计算样本量       # NormalIndPower():正态分布样本独立检验，solve_power():所需样本量
required_n = sms.NormalIndPower().solve_power(
    effect_size,
    power=0.8,  # 统计功效
    alpha=0.05,  # 显著水平
    ratio=1  # 两组样本的比例
)
print(np.ceil(required_n))

# 总样本量为9440（4720*2），假设平均活跃用户为1000，则实验周期为9440/1000=10天左右
