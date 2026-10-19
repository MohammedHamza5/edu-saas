const { executeSql } = require('./supabase_api_client.cjs');

const query = process.argv[2];
if (!query) {
  console.error('Please provide a SQL query as an argument');
  process.exit(1);
}

executeSql(query)
  .then(res => {
    console.log(JSON.stringify(res, null, 2));
  })
  .catch(err => {
    console.error('Execution Error:', JSON.stringify(err, null, 2));
    process.exit(1);
  });
