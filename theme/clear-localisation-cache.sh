#!/bin/sh
# Clear localisation cache so new mm_* keys appear in menu
php -r '
$di = null;
try {
  // Prefer Redis flush of LocalisationArray keys
  $redis = new Redis();
  $ok = @$redis->connect("127.0.0.1", 6379, 1.5);
  if ($ok) {
    $keys = $redis->keys("LocalisationArray:*");
    foreach ($keys as $k) { $redis->del($k); echo "del $k\n"; }
    // also phalcon/managed cache prefixes
    foreach ($redis->keys("*Localisation*") as $k) { $redis->del($k); echo "del $k\n"; }
    echo "redis ok\n";
  } else {
    echo "redis connect fail\n";
  }
} catch (Throwable $e) {
  echo "redis err ".$e->getMessage()."\n";
}
'
# Fallback: delete any file caches
find /storage/usbdisk1/mikopbx/tmp -type f \( -name "*Localisation*" -o -name "*localisation*" -o -name "*messages*" \) -delete 2>/dev/null || true
php -r "if(function_exists(\"opcache_reset\")){opcache_reset(); echo \"opcache_reset\n\";}"
echo "localisation cache cleared"
