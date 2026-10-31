const dns = require('node:dns');

try {
  dns.setDefaultResultOrder('ipv4first');
} catch (_) {}

const origLookup = dns.lookup;
dns.lookup = function (hostname, options, callback) {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }
  if (!options) options = {};
  if (typeof options === 'number') {
    options = { family: 4 };
  } else {
    options.family = 4;
  }
  if (hostname === 'vfjialpvgorpslqjdqwq.supabase.co') {
    if (options && options.all) {
      return callback(null, [{ address: '104.18.38.10', family: 4 }]);
    }
    return callback(null, '104.18.38.10', 4);
  }
  return origLookup.call(this, hostname, options, callback);
};

if (dns.promises && dns.promises.lookup) {
  const origPromisesLookup = dns.promises.lookup;
  dns.promises.lookup = async function (hostname, options) {
    if (!options) options = {};
    if (typeof options === 'number') {
      options = { family: 4 };
    } else {
      options.family = 4;
    }
    if (hostname === 'vfjialpvgorpslqjdqwq.supabase.co') {
      if (options && options.all) {
        return [{ address: '104.18.38.10', family: 4 }];
      }
      return { address: '104.18.38.10', family: 4 };
    }
    return origPromisesLookup.call(this, hostname, options);
  };
}
