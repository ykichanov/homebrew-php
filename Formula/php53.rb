require 'formula'

def postgres_installed?
  `which pg_config`.length > 0
end

class Php53 < Formula
  homepage 'http://php.net'
  url 'http://www.php.net/get/php-5.3.15.tar.bz2/from/this/mirror'
  md5 '5cfcfd0fa4c4da7576f397073e7993cc'
  version '5.3.15'

  # So PHP extensions don't report missing symbols
  skip_clean ['bin', 'sbin']

  depends_on 'freetds' if ARGV.include? '--with-mssql'
  depends_on 'gettext'
  depends_on 'gmp' if ARGV.include? '--with-gmp'
  depends_on 'icu4c' if ARGV.include? '--with-intl'
  depends_on 'imap-uw' if ARGV.include? '--with-imap'
  depends_on 'jpeg'
  depends_on 'libevent' if ARGV.include? '--with-fpm'
  depends_on 'libxml2'
  depends_on 'mcrypt'
  depends_on 'openssl' if ARGV.include? '--with-homebrew-openssl'
  depends_on 'tidy' if ARGV.include? '--with-tidy'
  depends_on 'unixodbc' if ARGV.include? '--with-unixodbc'
  depends_on 'homebrew/dupes/zlib'

  # Sanity Checks
  mysql_opts = [ '--with-libmysql', '--with-mariadb', '--with-mysql' ]
  if ARGV.length - (ARGV - mysql_opts).length > 1
    raise "Cannot specify more than one MySQL variant to build against."
  end

  if ARGV.include? '--with-pgsql'
    depends_on 'postgresql' => :recommended unless postgres_installed?
  end

  if ARGV.include? '--with-cgi' and ARGV.include? '--with-fpm'
    raise "Cannot specify more than one executable to build."
  end

  if ARGV.include? '--with-cgi' or ARGV.include? '--with-fpm'
    ARGV << '--without-apache' unless ARGV.include? '--without-apache'
  end

  def options
   [
     ['--with-libmysql', 'Include (old-style) libmysql support'],
     ['--with-mariadb', 'Include MariaDB support'],
     ['--with-mysql', 'Include MySQL support'],
     ['--with-pgsql', 'Include PostgreSQL support'],
     ['--with-mssql', 'Include MSSQL-DB support'],
     ['--with-unixodbc', 'Include unixODBC support'],
     ['--with-cgi', 'Enable building of the CGI executable (implies --without-apache)'],
     ['--with-fpm', 'Enable building of the fpm SAPI executable (implies --without-apache)'],
     ['--without-apache', 'Build without shared Apache 2.0 Handler module'],
     ['--with-intl', 'Include internationalization support'],
     ['--with-imap', 'Include IMAP extension'],
     ['--with-gmp', 'Include GMP support'],
     ['--with-suhosin', 'Include Suhosin patch'],
     ['--with-tidy', 'Include Tidy support'],
     ['--without-pear', 'Build without PEAR'],
     ['--with-homebrew-openssl', 'Include OpenSSL support via Homebrew'],
   ]
  end

  def patches
    "http://download.suhosin.org/suhosin-patch-5.3.9-0.9.10.patch.gz" if ARGV.include? '--with-suhosin'
  end

  def config_path
    etc+"php/5.3"
  end

  def home_path
    File.expand_path("~")
  end

  def install
    # Not removing all pear.conf's from PHP path results in the PHP
    # configure not properly setting the pear binary to be installed
    config_pear = "#{config_path}/pear.conf"
    user_pear = "#{home_path}/pear.conf"
    if File.exists?(config_pear) || File.exists?(user_pear)
      opoo "Backing up all known pear.conf files"
      opoo <<-INFO
If you have a pre-existing pear install outside
         of homebrew-php, and you are using a non-standard
         pear.conf location, installation may fail.
INFO
      FileUtils.mv(config_pear, "#{config_pear}-backup") if File.exists? config_pear
      FileUtils.mv(user_pear, "#{user_pear}-backup") if File.exists? user_pear
    end

    begin
      _install
      FileUtils.rm_f("#{config_pear}-backup") if File.exists? "#{config_pear}-backup"
      FileUtils.rm_f("#{user_pear}-backup") if File.exists? "#{user_pear}-backup"
    rescue Exception => e
      FileUtils.mv("#{config_pear}-backup", config_pear) if File.exists? "#{config_pear}-backup"
      FileUtils.mv("#{user_pear}-backup", user_pear) if File.exists? "#{user_pear}-backup"
      throw e
    end
  end

  def _install
    args = [
      "--prefix=#{prefix}",
      "--disable-debug",
      "--localstatedir=#{var}",
      "--sysconfdir=#{config_path}",
      "--with-config-file-path=#{config_path}",
      "--with-config-file-scan-dir=#{config_path}/conf.d",
      "--with-iconv-dir=/usr",
      "--enable-dba",
      "--with-ndbm=/usr",
      "--enable-exif",
      "--enable-soap",
      "--enable-sqlite-utf8",
      "--enable-wddx",
      "--enable-ftp",
      "--enable-sockets",
      "--enable-zip",
      "--enable-pcntl",
      "--enable-shmop",
      "--enable-sysvsem",
      "--enable-sysvshm",
      "--enable-sysvmsg",
      "--enable-mbstring",
      "--enable-mbregex",
      "--enable-zend-multibyte",
      "--enable-bcmath",
      "--enable-calendar",
      "--with-zlib=#{Formula.factory('zlib').prefix}",
      "--with-bz2=/usr",
      "--with-ldap",
      "--with-ldap-sasl=/usr",
      "--with-xmlrpc",
      "--with-kerberos=/usr",
      "--with-libxml-dir=#{Formula.factory('libxml2').prefix}",
      "--with-xsl=/usr",
      "--with-curl=/usr",
      "--with-gd",
      "--enable-gd-native-ttf",
      "--with-freetype-dir=/usr/X11",
      "--with-mcrypt=#{Formula.factory('mcrypt').prefix}",
      "--with-jpeg-dir=#{Formula.factory('jpeg').prefix}",
      "--with-png-dir=/usr/X11",
      "--with-gettext=#{Formula.factory('gettext').prefix}",
      "--with-snmp=/usr",
      "--with-mhash",
      "--with-libedit",
      "--mandir=#{man}",
    ]

    if ARGV.include? '--with-homebrew-openssl'
      args << "--with-openssl=" + Formula.factory('openssl').prefix.to_s
    else
      args << "--with-openssl=/usr"
    end

    if ARGV.include? '--with-fpm'
      args << "--enable-fpm"
      args << "--with-fpm-user=_www"
      args << "--with-fpm-group=_www"
      (prefix+'var/log').mkpath
      touch prefix+'var/log/php-fpm.log'
      (prefix+'homebrew-php.josegonzalez.php53.plist').write php_fpm_startup_plist
      (prefix+'homebrew-php.josegonzalez.php53.plist').chmod 0644
    elsif ARGV.include? '--with-cgi'
      args << "--enable-cgi"
    end

    # Build Apache module by default
    unless ARGV.include? '--without-apache'
      args << "--with-apxs2=/usr/sbin/apxs"
      args << "--libexecdir=#{libexec}"
    end

    if ARGV.include? '--with-gmp'
      args << "--with-gmp=#{Formula.factory('gmp').prefix}"
    end

    if ARGV.include? '--with-imap'
      args << "--with-imap=#{Formula.factory('imap-uw').prefix}"
      args << "--with-imap-ssl=/usr"
    end

    if ARGV.include? '--with-intl'
      args << "--enable-intl"
      args << "--with-icu-dir=#{Formula.factory('icu4c').prefix}"
    end

    if ARGV.include? '--with-mssql'
      args << "--with-mssql=#{Formula.factory('freetds').prefix}"
      args << "--with-pdo-dblib=#{Formula.factory('freetds').prefix}"
    end

    if ARGV.include? '--with-libmysql'
      args << "--with-mysql-sock=/tmp/mysql.sock"
      args << "--with-mysqli=/usr/local/bin/mysql_config"
      args << "--with-mysql=/usr/local"
      args << "--with-pdo-mysql=/usr/local"
    end

    if ARGV.include? '--with-mysql' or ARGV.include? '--with-mariadb'
      args << "--with-mysql-sock=/tmp/mysql.sock"
      args << "--with-mysqli=mysqlnd"
      args << "--with-mysql=mysqlnd"
      args << "--with-pdo-mysql=mysqlnd"
    end

    if ARGV.include? '--with-pgsql' and File.directory? Formula.factory('postgresql').prefix.to_s
      args << "--with-pgsql=#{Formula.factory('postgresql').prefix}"
      args << "--with-pdo-pgsql=#{Formula.factory('postgresql').prefix}"
    elsif ARGV.include? '--with-pgsql'
      args << "--with-pgsql=#{`pg_config --includedir`}"
      args << "--with-pdo-pgsql=#{`which pg_config`}"
    end

    if ARGV.include? '--with-tidy'
      args << "--with-tidy=#{Formula.factory('tidy').prefix}"
    end

    if ARGV.include? '--with-unixodbc'
      args << "--with-unixODBC=#{Formula.factory('unixodbc').prefix}"
      args << "--with-pdo-odbc=unixODBC,#{Formula.factory('unixodbc').prefix}"
    else
      args << "--with-iodbc"
      args << "--with-pdo-odbc=generic,/usr,iodbc"
    end

    system "./configure", *args

    unless ARGV.include? '--without-apache'
      # Use Homebrew prefix for the Apache libexec folder
      inreplace "Makefile",
        "INSTALL_IT = $(mkinstalldirs) '$(INSTALL_ROOT)/usr/libexec/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='$(INSTALL_ROOT)/usr/libexec/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so",
        "INSTALL_IT = $(mkinstalldirs) '#{libexec}/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='#{libexec}/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so"
    end

    if ARGV.include? '--with-intl'
      inreplace 'Makefile' do |s|
        s.change_make_var! "EXTRA_LIBS", "\\1 -lstdc++"
      end
    end

    if ARGV.include? '--without-pear'
      args << "--without-pear"
    end

    system "make"
    ENV.deparallelize # parallel install fails on some systems
    system "make install"

    config_path.install "./php.ini-development" => "php.ini" unless File.exists? config_path+"php.ini"
    chmod_R 0775, lib+"php"
    system bin+"pear", "config-set", "php_ini", config_path+"php.ini" unless ARGV.include? '--without-pear'
    if ARGV.include?('--with-fpm') and not File.exists? config_path+"php-fpm.conf"
      config_path.install "sapi/fpm/php-fpm.conf"
      inreplace config_path+"php-fpm.conf" do |s|
        s.sub!(/^;?daemonize\s*=.+$/,'daemonize = no')
        s.sub!(/^;include\s*=.+$/,";include=#{config_path}/fpm.d/*.conf")
        s.sub!(/^;?pm\.max_children\s*=.+$/,'pm.max_children = 10')
        s.sub!(/^;?pm\.start_servers\s*=.+$/,'pm.start_servers = 3')
        s.sub!(/^;?pm\.min_spare_servers\s*=.+$/,'pm.min_spare_servers = 2')
        s.sub!(/^;?pm\.max_spare_servers\s*=.+$/,'pm.max_spare_servers = 5')
      end
    end
  end

 def caveats; <<-EOS
For 10.5 and Apache:
    Apache needs to run in 32-bit mode. You can either force Apache to start
    in 32-bit mode or you can thin the Apache executable.

To enable PHP in Apache add the following to httpd.conf and restart Apache:
    LoadModule php5_module    #{libexec}/apache2/libphp5.so

The php.ini file can be found in:
    #{config_path}/php.ini

If pear complains about permissions, 'Fix' the default PEAR permissions and config:
    chmod -R ug+w #{lib}/php
    pear config-set php_ini #{etc}/php/5.3/php.ini

If you are having issues with custom extension compiling, ensure that this php is
in your PATH:
    PATH="$(brew --prefix josegonzalez/php/php53)/bin:$PATH"

If you have installed the formula with --with-fpm, to launch php-fpm on startup:
    * If this is your first install:
        mkdir -p ~/Library/LaunchAgents
        cp #{prefix}/homebrew-php.josegonzalez.php53.plist ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/homebrew-php.josegonzalez.php53.plist

    * If this is an upgrade and you already have the homebrew-php.josegonzalez.php53.plist loaded:
        launchctl unload -w ~/Library/LaunchAgents/homebrew-php.josegonzalez.php53.plist
        cp #{prefix}/homebrew-php.josegonzalez.php53.plist ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/homebrew-php.josegonzalez.php53.plist

You may also need to edit the plist to use the correct "UserName".

Please note that the plist was called 'org.php-fpm.plist' in old versions
of this formula.
   EOS
 end

  def test
    if ARGV.include?('--with-fpm')
      system "#{sbin}/php-fpm -y #{config_path}/php-fpm.conf -t"
    end
  end

  def php_fpm_startup_plist; <<-EOPLIST.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>homebrew-php.josegonzalez.php53</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{sbin}/php-fpm</string>
        <string>--fpm-config</string>
        <string>#{config_path}/php-fpm.conf</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>UserName</key>
      <string>#{`whoami`.chomp}</string>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
      <key>StandardErrorPath</key>
      <string>#{prefix}/var/log/php-fpm.log</string>
    </dict>
    </plist>
    EOPLIST
  end
end