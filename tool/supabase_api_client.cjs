const dns = require('dns');
const https = require('https');

// DNS Override for api.supabase.com to bypass local Egyptian ISP DNS block
const origLookup = dns.lookup;
dns.lookup = (hostname, options, callback) => {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }
  if (hostname === 'api.supabase.com') {
    if (options && options.all) {
      return callback(null, [{ address: '104.18.42.230', family: 4 }]);
    }
    return callback(null, '104.18.42.230', 4);
  }
  return origLookup(hostname, options, callback);
};

const PROJECT_REF = process.env.SUPABASE_PROJECT_REF || 'vfjialpvgorpslqjdqwq';
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';

async function executeSql(query) {
  const payload = JSON.stringify({ query });
  
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'api.supabase.com',
      port: 443,
      path: `/v1/projects/${PROJECT_REF}/database/query`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (res.statusCode >= 400) {
            reject({ status: res.statusCode, error: parsed });
          } else {
            resolve(parsed);
          }
        } catch (e) {
          if (res.statusCode >= 400) {
            reject({ status: res.statusCode, body });
          } else {
            resolve(body);
          }
        }
      });
    });

    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function getProjectDetails() {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'api.supabase.com',
      port: 443,
      path: `/v1/projects/${PROJECT_REF}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          resolve(body);
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function listEdgeFunctions() {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'api.supabase.com',
      port: 443,
      path: `/v1/projects/${PROJECT_REF}/functions`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          resolve(body);
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

module.exports = {
  PROJECT_REF,
  ACCESS_TOKEN,
  executeSql,
  getProjectDetails,
  listEdgeFunctions
};

if (require.main === module) {
  (async () => {
    try {
      console.log('Testing connection to Supabase Project:', PROJECT_REF);
      const proj = await getProjectDetails();
      console.log('Connected! Project Name:', proj.name, '| Status:', proj.status, '| Region:', proj.region);

      console.log('\nTesting Database Query via Management API...');
      const dbRes = await executeSql('SELECT current_database(), current_user, version();');
      console.log('Query Result:', JSON.stringify(dbRes, null, 2));

      console.log('\nListing Edge Functions...');
      const functions = await listEdgeFunctions();
      console.log('Functions Count:', Array.isArray(functions) ? functions.length : 0);
      if (Array.isArray(functions)) {
        functions.forEach(f => console.log(` - ${f.slug || f.name} (status: ${f.status}, version: ${f.version})`));
      }
    } catch (err) {
      console.error('API Error:', err);
    }
  })();
}
