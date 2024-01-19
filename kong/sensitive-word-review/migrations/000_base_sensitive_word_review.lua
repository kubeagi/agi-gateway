return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "sensitive_word" (
        "identifier"   TEXT                         NOT NULL,
        "value"        TEXT,
        PRIMARY KEY ("identifier")
      );
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS sensitive_word(
        value  text
        PRIMARY KEY ((value))
      );
    ]],
  },
}
