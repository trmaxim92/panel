#!/bin/sh
# Clear Phalcon ManagedCache localisation entries across Redis DBs
php -r '
try {
  $redis = new Redis();
  if (!@$redis->connect("127.0.0.1", 6379, 2.0)) {
    echo "redis connect fail\n";
    exit(0);
  }
  $deleted = 0;
  for ($db = 0; $db < 16; $db++) {
    $redis->select($db);
    $patterns = [
      "*Localisation*",
      "*localisation*",
      "_PH_MANAGED_CACHE:LocalisationArray:*",
      "LocalisationArray:*",
    ];
    foreach ($patterns as $p) {
      $keys = $redis->keys($p);
      foreach ($keys as $k) {
        $redis->del($k);
        echo "db{$db} del {$k}\n";
        $deleted++;
      }
    }
  }
  echo "deleted={$deleted}\n";
  echo "redis ok\n";
} catch (Throwable $e) {
  echo "redis err ".$e->getMessage()."\n";
}
'
find /storage/usbdisk1/mikopbx/tmp -type f \( -name "*Localisation*" -o -name "*localisation*" -o -name "*messages*" \) -delete 2>/dev/null || true
rm -rf /storage/usbdisk1/mikopbx/tmp/volt /storage/usbdisk1/mikopbx/tmp/volt_cache 2>/dev/null || true
php -r 'if(function_exists("opcache_reset")){opcache_reset(); echo "opcache_reset\n";}'
echo "localisation cache cleared"
