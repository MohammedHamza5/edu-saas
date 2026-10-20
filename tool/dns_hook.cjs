const dns = require('dns');
const origLookup = dns.lookup;

const hosts = {
  'api.supabase.com': '104.18.42.230',
  'firebase.googleapis.com': '172.217.116.4',
  'firebasehosting.googleapis.com': '172.217.116.4',
  'cloudresourcemanager.googleapis.com': '172.217.116.4',
  'identitytoolkit.googleapis.com': '172.217.116.4',
  'accounts.google.com': '172.217.116.4',
  'oauth2.googleapis.com': '172.217.116.4',
  'www.googleapis.com': '172.217.116.4',
  'upload.web.app': '199.36.158.100',
  'storage.googleapis.com': '34.3.0.27'
};

dns.lookup = (hostname, options, callback) => {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }
  if (hosts[hostname]) {
    if (options && options.all) {
      return callback(null, [{ address: hosts[hostname], family: 4 }]);
    }
    return callback(null, hosts[hostname], 4);
  }
  if (hostname.endsWith('.googleapis.com') || hostname.endsWith('.google.com')) {
    const ip = '172.217.116.4';
    if (options && options.all) {
      return callback(null, [{ address: ip, family: 4 }]);
    }
    return callback(null, ip, 4);
  }
  return origLookup(hostname, options, callback);
};
