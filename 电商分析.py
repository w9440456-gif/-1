import pandas as pd
import time

# 注释快捷键：command+/
start_time = time.time()
n_rows = 3000000
df = pd.read_csv('/Users/happy/Desktop/data/UserBehavior.csv', nrows=n_rows)  # 原数据为1亿，太大了，跑不动，取三百万条数据就行
df.to_csv('/Users/happy/Desktop/data/new_file.csv', index=False)  # 导出的dataframe不要索引
elapsed_time = time.time() - start_time
print(f'数据处理完成，共耗时：{elapsed_time}秒')

import pandas as pd

# 定义标题（避免sql关键字）
column_names = ['user_id',
                'product_id',
                'category_id',
                'action_type',
                'event_timestamp']
df = pd.read_csv('/Users/happy/Desktop/data/new_file.csv', names=column_names)
# 将时间戳转换为日期格式
df['times'] = pd.to_datetime(df['event_timestamp'], unit='s') + pd.Timedelta(hours=8)
df.info()
# 提取日期和时间信息
df['dates'] = df['times'].dt.date
df['hours'] = df['times'].dt.hour
df['weekdays'] = df['times'].dt.day_name()

# 查看dataframe的行数，列数以及前几列
rows, columns = df.shape
print(rows, columns)

# 打印出csv格式的dataFram：以制表符为分割，用nan来填充空值(只是为了在python里看些数据)
print(df[{'user_id',
          'product_id',
          'action_type',
          'times', 'dates',
          'hours', 'weekdays'}].head().to_csv(sep='\t',
                                              na_rep='nan'))

# 定义日期时间范围范围
start_date = pd.to_datetime('2017-11-25 00:00:00')
end_date = pd.to_datetime('2017-12-03 23:59:59')

# 过滤日期范围外的数据
original_rows = len(df)  # 原本的行数
print(original_rows)
df = df[(df['times'] > start_date) & (df['times'] < end_date)]
filtered_rows = len(df)  # 过滤后的行数
filtered_percentage = (filtered_rows / original_rows) * 100 if original_rows > 0 else 0
print(original_rows, filtered_rows, filtered_percentage)

# 检查缺失值
print('\n缺失值统计：')
print(df.isnull().sum())

# 检查重复值
print('\n重复值统计：')
duplicate_count = df.duplicated().sum()
print(f'删除前重复值数量：{duplicate_count}')
df = df.drop_duplicates()
print(f'删除后重复值的数量{df.duplicated().sum()}')

df.to_csv('/Users/happy/Desktop/data/tbub.csv', index=False)  # 导出的dataframe不要索引
