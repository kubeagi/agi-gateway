return {
  {
    name               = "sensitive_word",
    primary_key        = { "identifier"},
    generate_admin_api = false,
    ttl                = false,
    db_export          = false,
    fields             = {
      {
        identifier = {
          type     = "string",
          required = true,
          len_min  = 0,
        },
      },
      {
        value = {
          type     = "string",
          required = true,
        },
      },
    },
  },
}
