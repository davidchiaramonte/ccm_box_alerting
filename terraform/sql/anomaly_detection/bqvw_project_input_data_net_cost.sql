with project_lifetime_spend as (
select project_id, project_name, sum(total_net_cost) as total_net_cost_past_365_days
from 
    `${union_project_daily_spend}`
where date_diff(current_date('US/Pacific'), usage_start_date, day) <= 365
group by 1,2
having total_net_cost_past_365_days>0
) 
select daily.usage_start_date, daily.project_id, daily.project_name, sum(daily.total_net_cost) as total_net_cost
from `${union_project_daily_spend}` daily
inner join project_lifetime_spend lifetime on daily.project_id = lifetime.project_id -- inner joining with lifetime spend table filters away projects with insufficient spend
where date_diff(current_date('US/Pacific'), daily.usage_start_date, day) <= 400
and usage_start_date <= date_sub(current_date('US/Pacific'), INTERVAL 2 DAY) --ensure best we can that data is from complete days
and daily.project_id IS NOT NULL
group by 1,2,3