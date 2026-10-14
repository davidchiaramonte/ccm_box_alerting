SELECT * FROM ML.EXPLAIN_FORECAST(MODEL `${project_net_cost_forecast}`,
    STRUCT(90 AS horizon, -- TODO: Make forecast horizon customizable
    0.99 AS confidence_level)); -- TODO: Make confidence customizable