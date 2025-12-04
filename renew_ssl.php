[200~<?php

echo "\n==============================\n";
echo "   LiteSpeed SSL Renew Tool   \n";
echo "==============================\n\n";

// Ask for domain if not passed as argument
if ($argc < 2) {
    echo "Enter domain name: ";
    $domain = trim(fgets(STDIN));
} else {
    $domain = $argv[1];
}

if (empty($domain)) {
    echo "❌ ERROR: Domain name cannot be empty!\n";
    exit(1);
}

echo "��� Starting SSL renewal for: $domain\n";

// Paths
$vhostConf = "/usr/local/lsws/conf/vhosts/$domain/vhconf.conf";

// Step 1: Stop LiteSpeed
echo "➡️ Stopping LiteSpeed...\n";
shell_exec("sudo systemctl stop lsws");

// Step 2: Renew SSL certificate
echo "➡️ Running Certbot standalone renewal...\n";
shell_exec("sudo certbot certonly --standalone -d $domain --force-renewal");

// Step 3: Detect latest certificate directory
echo "➡️ Detecting latest certificate directory...\n";
$certDir = trim(shell_exec("ls -dt /etc/letsencrypt/live/$domain* | head -1"));

if (!is_dir($certDir)) {
    echo "❌ ERROR: Certificate directory not found! ($certDir)\n";
    echo "Did certbot issue fail?\n";
    exit(1);
}

echo "✔ Using certificate folder: $certDir\n";

// Step 4: Update vhost config
echo "➡️ Updating vhost configuration...\n";

$replace = [
    'keyFile'   => "keyFile                 $certDir/privkey.pem",
    'certFile'  => "certFile                $certDir/fullchain.pem",
    'certChain' => "certChain               $certDir/fullchain.pem",
];

foreach ($replace as $key => $newValue) {
    shell_exec("sudo sed -i \"s|$key.*|$newValue|\" $vhostConf");
}

echo "✔ vhost config updated.\n";

// Step 5: Start LiteSpeed
echo "➡️ Starting LiteSpeed...\n";
shell_exec("sudo systemctl start lsws");

// Step 6: Verify certificate
echo "➡️ Verifying SSL status...\n";
$verify = shell_exec("openssl s_client -connect $domain:443 -servername $domain </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer");

echo $verify . "\n";

echo "✅ COMPLETED: SSL renewed and assigned successfully for $domain\n\n";

