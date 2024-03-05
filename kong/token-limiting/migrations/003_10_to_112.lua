return {
  postgres = {
    up = [[
      CREATE INDEX IF NOT EXISTS tokenlimiting_metrics_idx ON tokenlimiting_metrics (service_id, route_id, period_date, period);
    ]],
  },

  cassandra = {
    up = [[
    ]],
  },
}
