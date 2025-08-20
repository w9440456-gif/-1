#查找重复行(确认重复值为0)
select user_id,product_id,dates,times
from tbub
group by user_id,product_id,dates,times
having count(*)>1;

## 用户分析
# 用户流量（pv:浏览总次数，uv:访客数（不同用户），pvuv:平均每个用户浏览的次数，也叫浏览深度 ）
create table df_pv_uv
(                              
dates varchar(10),             #varchar:可变的10个内字符
PV int(9),
UV int(9),
PVUV decimal(10,2)
);

INSERT INTO df_pv_uv
select 
dates,
count(if(action_type='pv',1,null)) as PV,
count(distinct user_id) as UV,
round(count(if(action_type='pv',1,null)) / count(distinct user_id),2) as PVUV
from tbub
group by dates;

# 用户留存（次日留存率）
create table df_rention_1(
dates CHAR(10),               #固定的10个字符，不够用空格填充，在mysql可能自动去除空格
rention_1 float);
insert into df_rention_1
select ub1.dates,
count(distinct ub2.user_id)/count(distinct ub1.user_id) as rention_1
from 
(select distinct user_id,dates
from tbub ) ub1
left join (select distinct user_id,dates
from tbub) ub2 on ub1.user_id=ub2.user_id and ub2.dates=date_add(ub1.dates,interval 1 day)
group by ub1.dates;

# 用户留存（次日留存率）
create table df_rention_3
(
dates CHAR(10),               #固定的10个字符，不够用空格填充，在mysql可能自动去除空格
rention_3 float);

insert into df_rention_3
select ub1.dates,
count(distinct ub2.user_id)/count(distinct ub1.user_id) as rention_3
from 
(select distinct user_id,dates
from tbub ) ub1
left join (select distinct user_id,dates
from tbub) ub2 on ub1.user_id=ub2.user_id and ub2.dates=date_add(ub1.dates,interval 3 day)
group by ub1.dates;

# 用户行为（pv:浏览数 cart；添加到购物车 fav;收藏 buy:买 ）根据每天每小时的情况分组
create table df_timeseries
(
dates varchar(10),
hours int(9),
PV int(9),
CART INT(9),
FAV int(9),
BUY INT(9)
);

INSERT INTO df_timeseries
select
dates,
hours,
count(if(action_type='pv',1,null)) as PV,
count(if(action_type='cart',1,null)) as CART,
count(if(action_type='fav',1,null)) as FAV,
count(if(action_type='buy',1,null)) as BUY
from tbub
group by dates,hours
order by dates,hours;


#用户行为路径：
-- 以单个用户的逻辑，按照用户id和品类id分组，统计每一个用户是否有执行PV、CART、FAV、BUY这四个步骤，
-- 再组合这些步骤成为用户的行为路径。会存在用户没有浏览行为直接购买的情况（如‘/-/-/-购买'），
-- 这是因为数据是从2017-11-25日开始，用户在2017-11-25日之前已经进行了其他步骤，我们不得而知，所以将这种情况需要排除，我们仅研究存在浏览行为的用户路径。
CREATE TABLE path AS WITH ubt AS (
  SELECT
    user_id,
    category_id,
    COUNT(IF(action_type = 'pv', 1, NULL)) AS PV,
    COUNT(IF(action_type = 'fav', 1, NULL)) AS FAV,
    COUNT(IF(action_type = 'cart', 1, NULL)) AS CART,
    COUNT(IF(action_type = 'buy', 1, NULL)) AS BUY
  FROM
    tbub
  GROUP BY
    user_id,
    category_id
),
ifubt AS (
  SELECT
    user_id,
    category_id,
    IF(PV > 0, 1, 0) AS ifpv,
    IF(FAV > 0, 1, 0) AS iffav,
    IF(CART > 0, 1, 0) AS ifcart,
    IF(BUY > 0, 1, 0) AS ifbuy
  FROM
    ubt
  GROUP BY
    user_id,
    category_id
),
user_path as (select user_id,category_id,concat(ifpv, iffav, ifcart, ifbuy) as path from ifubt) 
select user_id,
  category_id,
  path,
  case
    when path = 1101 then '浏览-收藏-/-购买'
	when path = 1011 then '浏览-/-加购-购买'
	when path = 1111 then '浏览-收藏-加购-购买'
	when path = 1001 then '浏览-/-/-购买'
	when path = 1010 then '浏览-/-加购-/-'
	when path = 1100 then '浏览-收藏-/-/-'
	when path = 1110 then '浏览-收藏-加购-/-'
	else '浏览-/-/-/'
  END as buy_path
from user_path
group by user_id,category_id 
having path regexp '^1';-- 仅研究有预览行为的用户路径 

# 漏斗模型（次数一层层往下递减）用户从浏览到购买的转化过程
create table funnel as 
select dates,
count(distinct case when action_type='pv' then user_id end ) as pv_num,
count(distinct case when action_type='fav' then user_id end ) as fav_num,
count(distinct case when action_type='cart' then user_id end ) as cart_num,
count(distinct case when action_type='buy' then user_id end ) as buy_num
from tbub
group by dates;

#用户画像
-- RMF 模型是客户关系管理（CRM）和营销分析中常用的一种客户分层模型，通过三个核心指标对客户价值进行量化评估：最近一次消费时间（Recency）：、消费频率（Frequency）、消费金额（Monetary），可以帮助企业识别高价值客户、制定精准营销策略。
-- 但是我们的数据集没有消费金额金额的记录，所以考虑将 “消费金额（Monetary）” 替换为 “收藏+加购（Cart&Favorite）” 后的次数，命名为RFC 模型。
-- 根据RFC模型将用户划分为8个类别。
create table df_rfc as 
with
r as (
select user_id,
max(dates) as recency
from tbub
where action_type = 'buy'
group by user_id
),
f as (
select user_id,
count(*) as frequency
from tbub
where action_type = 'buy'
group by user_id
),
c as (
select user_id,
count(*) as cart_fav_count
from tbub
where action_type in ('cart','fav')  -- 统计加购和收藏
group by user_id
),
rfc_base as (
select r.user_id,
r.recency,
f.frequency,
c.cart_fav_count 
from r
left join f on r.user_id=f.user_id
left join c on r.user_id=c.user_id
),
rfc_scores as (
select user_id,
recency,
case 
  when recency = '2017-12-03' then 100
  when recency between '2017-12-02' and '2017-12-01' then 80
  when recency between '2017-11-30' and '2017-11-29' then 60
  when recency between '2017-11-28' and '2017-11-27' then 40
  else 20 
end as r_score,
frequency,
case 
  when frequency > 15 then 100
  when frequency between 12 and 14 then 90
  when frequency between 9 and 11 then 70
  when frequency between 6 and 8 then 50
  when frequency between 3 and 5 then 30
  else 10
  end as f_score,
cart_fav_count,
case 
  when cart_fav_count >20 then 100
  when cart_fav_count between 16 and 20 then 85
  when cart_fav_count between 11 and 15 then 70
  when cart_fav_count between 6 and 10 then 55
  when cart_fav_count between 1 and 5 then 40
  else 20
end as c_score
from rfc_base
)

SELECT 
    t1.user_id,
    recency,
    r_score,
    avg_r,
    frequency,
    f_score,
    avg_f,
    cart_fav_count,
    c_score,
    avg_c,
    CASE    
        WHEN (f_score >= avg_f AND r_score >= avg_r AND c_score >= avg_c) THEN '价值用户'    
        WHEN (f_score >= avg_f AND r_score >= avg_r AND c_score < avg_c) THEN '潜力用户'    
        WHEN (f_score >= avg_f AND r_score < avg_r AND c_score >= avg_c) THEN '活跃用户'    
        WHEN (f_score >= avg_f AND r_score < avg_r AND c_score < avg_c) THEN '保持用户'    
        WHEN (f_score < avg_f AND r_score >= avg_r AND c_score >= avg_c) THEN '发展用户'    
        WHEN (f_score < avg_f AND r_score >= avg_r AND c_score < avg_c) THEN '新用户'    
        WHEN (f_score < avg_f AND r_score < avg_r AND c_score >= avg_c) THEN '兴趣用户'    
        ELSE '挽留用户'    
    END AS user_class     
FROM rfc_scores AS t1
LEFT JOIN 
(
    SELECT    
        user_id,    
        AVG(r_score) OVER() AS avg_r,    
        AVG(f_score) OVER() AS avg_f,
        AVG(c_score) OVER() AS avg_c    
    FROM    
        rfc_scores
) AS t2 ON t1.user_id = t2.user_id;

-- rfc模型用户计数
create table rfc_count as 
select user_class,
count(*) as user_class_count
from df_rfc
group by user_class;

## 商品分析（简单查询有八十多万商品，6千多类别）
-- 热卖商品top1000产品
create table product_buy_hot as 
select product_id,
count(if(action_type = 'buy',1,null)) as product_buy
from tbub
group by product_id
order by product_buy desc
limit 1000;

-- 热卖商品top100类别
create table category_buy_hot as 
select category_id,
count(if(action_type = 'buy',1,null)) as category_buy
from tbub
group by category_id
order by category_buy desc
limit 100;

# 品类决策时长（用户从首次预览到首次购买的时间）
create table category_pv_buy_time as 
-- 筛选有购买行为的用户——品类对
with bought_categories as (
select distinct user_id,category_id  # 这里是对user_id和category_id一起去重,只有当user和category同时相同才去重
from tbub
where action_type='buy'
),
-- 计算每个用户——品类对的首次浏览时间
first_pv as (
select t.user_id,t.category_id, min(times) as first_pv_time
from tbub t
join bought_categories bc on t.user_id = bc.user_id and t.category_id = bc.category_id
where action_type = 'pv'
group by t.user_id,t.category_id
),
-- 计算每个用户——品类对的首次购买时间
first_buy as(
select t.user_id,t.category_id,min(times) as first_buy_time
from tbub t
join bought_categories bc on t.user_id = bc.user_id and t.category_id = bc.category_id
where action_type = 'buy'
group by t.user_id,t.category_id
),
-- 计算每个用户——品类的转化时间
user_category_conversion as (
select p.user_id,p.category_id,
p.first_pv_time,
b.first_buy_time,
timestampdiff(second, p.first_pv_time, b.first_buy_time) as conversion_seconds 
from first_pv p
inner join first_buy b on p.user_id=b.user_id   
and p.category_id = b.category_id
and p.first_pv_time < b.first_buy_time   -- 确保浏览发生在购物前
),
-- 同类别的平均转化时间
category_avg_conversion as (
select category_id,
avg(conversion_seconds)  as avg_conversion_seconds,
avg(conversion_seconds)/3600 as avg_conversion_hours
from user_category_conversion
group by category_id
)
SELECT 
    ucc.user_id,
    ucc.category_id,
    ucc.first_pv_time,
    ucc.first_buy_time,
    ucc.conversion_seconds / 3600 AS conversion_hours,  -- 转为小时显示
    cat.avg_conversion_hours,
    (ucc.conversion_seconds / 3600) - cat.avg_conversion_hours AS hours_deviation  -- 与品类平均值的偏差
FROM user_category_conversion ucc
JOIN category_avg_conversion cat 
    ON ucc.category_id = cat.category_id
WHERE 
    ucc.first_pv_time > '2017-11-25'
ORDER BY 
    ucc.category_id,
    ucc.user_id;
    
# 品类流量
-- 统计每个品类在每个小时的流量
create table category_hours_flow as
select category_id,hours,
sum(if(action_type='pv',1,0)) as pv,
sum(if(action_type='cart',1,0)) as cart,
sum(if(action_type='fav',1,0)) as fav,
sum(if(action_type='buy',1,0)) as buy
from tbub 
group by category_id,hours
order by category_id,hours;
-- 统计每个品类在每天小时的流量
create table category_daily_flow as
select category_id,dates,
sum(if(action_type='pv',1,0)) as pv,
sum(if(action_type='cart',1,0)) as cart,
sum(if(action_type='fav',1,0)) as fav,
sum(if(action_type='buy',1,0)) as buy
from tbub 
group by category_id,dates
order by category_id,dates;

# 品类特征
select category_id,
count(if(action_type = 'pv',1,null)) as pv_num,
count(if(action_type = 'fav',1,null)) as cart_num,
count(if(action_type = 'cart',1,null)) as fav_num,
count(if(action_type = 'buy',1,null)) as buy_num
from tbub
group by category_id;






