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
  # MariaDB Database
  services.mysql = {
    enable = true;
    initialDatabases = [{name = "wordpress";}];
    ensureUsers = [
      {
        name = "wordpress";
        password = "password";
        ensurePermissions = {
          "wordpress.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  # Caddy Web Server
  services.caddy = {
    enable = true;
    virtualHosts."http://localhost:8080" = {
      extraConfig = ''
        # UPDATED: Point Caddy directly to your existing "wordpress" folder
        root * ${config.env.DEVENV_ROOT}/public
        php_fastcgi 127.0.0.1:9000
        file_server
      '';
    };
  };

  # --- 3. TASKS ---
  tasks = {
    "wordpress:setup" = {
      exec = ''
        cd public

        # We skip downloading since you already have the files.
        # Just check if wp-config.php needs to be generated.
        if [ ! -f "wp-config.php" ]; then
          echo "Generating wp-config.php..."
          wp config create \
            --dbname=wordpress \
            --dbuser=wordpress \
            --dbpass=password \
            --dbhost=127.0.0.1 \
            --skip-salts
        else
          echo "wp-config.php already exists. Database connection ready!"
        fi
      '';
      before = ["devenv:enterShell"];
    };
  };

  # --- 4. PACKAGES ---
  packages = [
    pkgs.phpPackages.composer
    pkgs.wp-cli
  ];
}
