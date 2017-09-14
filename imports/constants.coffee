module.exports =
  GRITS_URL: process.env.GRITS_URL or "https://grits.eha.io"
  GRITS_API_KEY: process.env.GRITS_API_KEY
  SPA_API_URL: process.env.SPA_API_URL or "http://spa.eha.io/api/v1"
  SQLITE_DB_PATH: process.env.SQLITE_DB_PATH or '/itisSqlite/ITIS.sqlite'
  MAX_SUBINTERVALS: 200000
