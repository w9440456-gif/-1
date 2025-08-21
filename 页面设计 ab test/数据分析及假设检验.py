import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import scipy.stats as stats
from statsmodels.stats.proportion import proportions_ztest, proportion_confint

data = pd.read_excel('/Users/happy/Desktop/data/ab_test.xlsx')
data.info()
#  统计缺失值(每一列)
print(data.isnull().sum())

#  重复值
# 统计数据重复值
print(data.duplicated().sum())
# 统计用户ID重复数
print(data['id'].duplicated().sum())

# 只保留在某一组有记录的用户（即删除某用户即在实验组有数据，也在对照组有数据）
repeat_id = data[data['id'].duplicated()]['id']  # 筛选ID重复的，取ID列
data_new = data[~data['id'].isin(repeat_id)]
data_new.info()
print(data_new['id'].duplicated().sum())

# 根据分组和落地页进行分组统计
print(pd.crosstab(data_new['con_treat'], data_new['page']))

# 处理时间，查看统计天数（结果为23天，该数据集符合实验周期，但该数据集的时间有问题）
# data_days = [i[0] for i in data["timestamp"].str.split(" ")]
# date_days


# 抽样：因为这里用的数据集很大，所以根据最小样本量（4720）抽样，这里每组抽取5000条样本。
# 实际情况下，是不需要抽样的，因为是根据实现计算好的样本量来部署AB测试，收集到的数据基本都是要用上的。
required_n = 5000
control_sample = data_new[data_new['con_treat'] == 'control'].sample(n=required_n)
treatment_sample = data_new[data_new['con_treat'] == 'treatment'].sample(n=required_n)
test_data = pd.concat([control_sample, treatment_sample], ignore_index=True)  # 合并两个样本，忽略之前两个组（列表）的索引
print(test_data)

#  交叉统计
print(pd.crosstab(test_data['con_treat'], test_data['page']))

#  计算两组样本转化率的平均值和标准差
# agg([np.mean,np.std])也可以运行，但可能会有些不兼容
conversion_rates = test_data.groupby('con_treat')['converted'].agg(mean=lambda x: np.mean(x),
                                                                   std=lambda x: np.std(x))
conversion_rates.columns = ['conversion_rate_mean', 'conversion_rate_std']
print(conversion_rates)

#  可视化转化率
plt.figure(figsize=(8, 6), dpi=60)
sns.barplot(x=test_data['con_treat'], y=test_data['converted'])
plt.ylim(0, 0.17)
plt.title('group conversion rate', fontsize=20)
plt.xlabel('group', fontsize=15)
plt.ylabel('conversion_rate', fontsize=15)
plt.show()

#  假设检验；实验目的是想要检验新落地页的转化率是否显著大于旧的，但不知道新的落地页的转化率一定比旧的好，故是
#   双侧检验：
#   H0：P0=P1
#   H1：P0≠P1 样本量足够大，总体方差未知，所以采用Z检验

# 计算样本转化的次数
control_result = test_data[test_data['con_treat'] == 'control']['converted']
treatment_result = test_data[test_data['con_treat'] == 'treatment']['converted']
test_counts = [control_result.count(), treatment_result.count()]
successes = [control_result.sum(), treatment_result.sum()]
print(test_counts)
print(successes)

#  计算Z值和P值
z_stats, p_val = proportions_ztest(successes, test_counts)
#  计算临界值
critical_value = stats.norm.ppf(1 - 0.025)
#  计算两组95%的置信区间
(lower_con, lower_treat), (upper_con, upper_treat) = proportion_confint(successes, test_counts, alpha=0.05)


#  打印结果
print(f'p_val:{p_val}:.3f')
print(f'z_statistics:{z_stats}:.2f')
print(f'临界值：{critical_value}:.2f')
print('落入拒绝域，拒绝原假设，两版本页面存在差异' if z_stats > critical_value else '落入接受域，两版本页面不存在差异')
print(f'i 95% for control group : [{lower_con:.3f}, {upper_con:.3f}]')
print(f'i 95% for treatment group : [{lower_treat:.3f}, {upper_treat:.3f}]')