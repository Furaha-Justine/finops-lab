const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

function getPool() {
  return new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 5432,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectionTimeoutMillis: 5000,
  });
}

app.get('/', (req, res) => {
  res.json({ service: 'fincorp-app', message: 'FinCorp CI/CD & DR demo API' });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/db-check', async (req, res) => {
  const pool = getPool();
  try {
    const result = await pool.query('SELECT NOW() AS current_time');
    res.status(200).json({
      status: 'connected',
      dbHost: process.env.DB_HOST,
      dbName: process.env.DB_NAME,
      currentTime: result.rows[0].current_time,
    });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  } finally {
    await pool.end();
  }
});

if (require.main === module) {
  app.listen(port, () => {
    console.log(`fincorp-app listening on port ${port}`);
  });
}

module.exports = { app };
