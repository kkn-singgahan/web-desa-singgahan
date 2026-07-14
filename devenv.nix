{
  pkgs,
  lib,
  config,
  ...
}: {
  # --- 1. LANGUAGES ---
  languages.php = {
    enable = true;
    extensions = ["mysqli" "gd" "intl" "mbstring" "zip"];
    fpm.pools.web = {
      listen = "127.0.0.1:9000";
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 5;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 3;
      };
    };
  };

  # --- 2. SERVICES ---
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    # Don't rely on initialDatabases/ensureUsers due to bug #2902
    # Use a process to set up DB and user instead
  };

  services.caddy = {
    enable = true;
    virtualHosts."http://localhost:8080" = {
      extraConfig = ''
        root * ${config.env.DEVENV_ROOT}/public
        php_fastcgi 127.0.0.1:9000
        file_server
      '';
    };
  };

  # --- 3. PROCESSES ---
  # Workaround for bug #2902: manually create DB and user after MySQL starts
  processes.mysql-setup = {
    exec = ''
      sleep 5
      ${pkgs.mariadb}/bin/mysql -uroot -e "CREATE DATABASE IF NOT EXISTS wordpress;" 2>/dev/null || true
      ${pkgs.mariadb}/bin/mysql -uroot -e "CREATE USER IF NOT EXISTS 'wordpress'@'localhost' IDENTIFIED BY 'password';" 2>/dev/null || true
      ${pkgs.mariadb}/bin/mysql -uroot -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';" 2>/dev/null || true
      ${pkgs.mariadb}/bin/mysql -uroot -e "FLUSH PRIVILEGES;" 2>/dev/null || true
      echo "MySQL setup complete"
      # Keep process alive so devenv doesn't restart it
      ${pkgs.coreutils}/bin/sleep infinity
    '';
  };

  # --- 4. TASKS ---
  tasks = {
    "wordpress:setup" = {
      exec = ''
        cd public
        if [ ! -f "wp-config.php" ]; then
          echo "Generating wp-config.php..."
          wp config create \
            --dbname=wordpress \
            --dbuser=wordpress \
            --dbpass=password \
            --dbhost=127.0.0.1 \
            --skip-salts
        else
          echo "wp-config.php already exists."
        fi
      '';
      before = ["devenv:enterShell"];
    };
  };

  # --- 5. PACKAGES ---
  packages = [
    pkgs.phpPackages.composer
    pkgs.wp-cli
  ];
}
