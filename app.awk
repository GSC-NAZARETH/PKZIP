#/system/bin/sh
awk ' 

function show_help(section,    useformat,title,syntax,options,desc,notes)
{ 
  
  if( section == "" ) section = "main"

while(1) {

	# section main help
if( section == "main" ) {
printf "\
Short Hand for calling common app command\
\
usage: app [command] [arg]\
\
--[command]--	--[description]--\
  install	install apk file\
  uninstall	uninstall installed app\
  backup	Backup installed app\
  restore	Restore app from backup repo\
  clone		Install intalled app to another user\
\
for help about command use:\
  app [--help] [command]\
"
break
}

if( section ~ /backup|restore/ ) {
  useformat = 1
  title = "App Backup & Restore/Backup App to Repository/Restore App from Repository/"
  syntax = "app [backup|restore] [options] package..."
  options = "-u [userId]/-oa/-od/-a/-r/"
  if( section == "backup" ) {
    desc = "Backup app from [userId]/Backup App only/Backup Data only/Backup app+data (default)/Remove Backup from repository/"
  } else {
    desc = "Restore app to [userId]/Restore App only/Restore data only (app must installed)/Restore app+data (default)/Remove Backup file from repository/"
  }
  notes = "use only 1 option as 1 arg, dont mix them"
  break
}

if( section ~ /^install$/ ) {
  useformat = 1
  title = "App Installer/Install apk file/"
  syntax = "app install [option] [file.apk[full path]].../"
  options = "-u [userId]/-g/"
  desc = "Install app to [target user]/grant all runtime permissions/"
  break
}

if( section == "uninstall" ) {
  useformat = 1
  title = "Uninstall app/"
  syntax = "app uninstall [option] package.../"
  options = "-u [UserId]/-k/-b/"
  desc =  "Uninstall app under user/Keep app data/Make Backup before uninstalling/"
  notes = "Use only 1 option in 1 argument"
  break
}

if( section == "clone" ) {
  useformat = 1
  title = "App Cloner/Install existing app to another user/"
  syntax = "app clone [options] package.../"
  options = "-u [userId]/-x/-oa/-od/-a/"
  desc = "Set dest [userId]/Exchange user source >|< dest/Clone app only (default)/Clone data only (Major Bugs)/Clone app+data (Major Bugs)"
  notes = "package must installed on source user, before doing anything\
default user:\
  source[0 [main]], dest[another available user]\
"
  break
}
break
} 

if( useformat ) {
  if( title ) {
    split(title, tmparr, "/")
    i = 0; while( tmparr[++i] )
      printf "%s\n", tmparr[i]
    print
  }
  if( syntax ) {
    print "syntax:"
    split(syntax, tmparr, "/")
    i = 0; while( tmparr[++i] )
	printf "  %s\n", tmparr[i]
    print
  }
  if( options ) {
    printf "%-12s\t%s\n", "Options:", "Description:"
    split(options, tmparr, "/")
    split(desc, tmparr2, "/")
    i = 0; while( tmparr[++i] )
	printf "  %-10s\t%s\n", tmparr[i], tmparr2[i]
    print
  }
  if( notes ) {
    print "Notes:"
    print notes
  }
  if( error_help ) {
    print "Error:"
    print error_help
  }
}
}

function exec(cmd,show,   a,i) {
  # show flag will print output
  #   default is sillent
  #   output saved in array SHELL
  #   also it return the last value

  split("", SHELL)
  while( (cmd | getline SHELL[++i]) ) {
    if( show ) print SHELL[i]
  }
  close(cmd)
  ret_exec = SHELL[i]
}

function backup_restore(command) {
  repo = "/sdcard/termux/etc/AppBackup/repo"
  user = 0
  br_app = br_data = 1

  # get available user
  if( sys_user == "" ) {
    exec("dumpsys user")
    sys_user = ":"
    for(a in SHELL)
      if( SHELL[a] ~ /UserInfo/ ) {
        gsub(/.*\{|:.*/, "", SHELL[a])
        sub(/$/, SHELL[a] ":", sys_user)
      }
  }

  while( ARGV[++I] ) {
    input = ARGV[I]
    if( input ~ /^-/ ) {
      if( input == "-od" ) { br_data = 1; br_app = 0; }
      if( input == "-oa" ) { br_data = 0; br_app = 1; }
      if( input == "-a" ) br_app = br_data = 1
      if( input == "-u" )
	if( index(sys_user, ":" ARGV[++I] ":") )
	  user = ARGV[I]
        else { 
	  print "user not available: " ARGV[I]
	  printf "Available user: {%s}\n", sys_user
	  break
	}
      continue
    }

    #  getting package info and installed status
    installed = current_installed = ""
    _get_app_info_(input)
    for(a in APP_INFO) {
      if( APP_INFO[a] ~ /installed=true/ ) {
	split(APP_INFO[a], tmparr)
	sub(/$/, tmparr[2], installed)
      }
    }

    if( installed ) sub(/^/, ":",installed)
    if( index(installed, ":" user ":") )
      current_installed = 1

    if( command == "backup" ) _backup_(input)
    if( command == "restore" ) _restore_(input)
  }
}

function app_cloner()
{
  do
  {
    user = 0
    cl_data = 0
    cl_app = 1
    exchange = dest = ""
    while( ARGV[++I] ) {
      input = ARGV[I]
      if( input == "-u" )
        { dest = ARGV[++I]; continue; }
      if( input == "-oa" )
	{ cl_app = 1; cl_data = 0; continue; }
      if( input == "-od" )
	{ cl_app = 0; cl_data = 1; continue; }
      if( input == "-a" )
	{ cl_app = 1; cl_data = 1; continue; }
      if( input == "-x" )
	{ exchange = 1; continue; }

      _clone_(input)
    }
  } while( done )
}

function _clone_(package,    installed,not_installed,done)
{
  do
  {
    if( package ) {
      _get_app_info_(package)
      installed = not_installed = ""
      for(i in APP_INFO) {
	if(APP_INFO[i] ~ /installed=false/)
	  sub(/$/, APP_INFO[i]"\n", not_installed)
	if(APP_INFO[i] ~ /installed=true/)
	  sub(/$/, APP_INFO[i]"\n", installed)
      }
      if(installed == "") {
	print "app not installed: " package
	break
      }
    } else break

    if(not_installed == "") {
      if( exchange ) {
	for(i in APP_INFO) {
	  if(APP_INFO[i] ~ /userId=/)
	    { uid = APP_INFO[i];\
	      gsub(/.*=/, "", uid); break; }
	}

	split(installed, tmparr, "\n")
	for( i in tmparr )
	  gsub(/^.*User |:.*$/, "", tmparr[i])
	source = tmparr[1]
	dest = tmparr[2]

	printf "* Exchanging Data: %s -> ", package
	cmd = sprintf("\
	  name=%s user1=%d user2=%d uid=%d;\
	  tmpdir=$(mktemp -d);\
	  path1=/data/user/$user1/$name \
	  path2=/data/user/$user2/$name ;\
	  (\
	    [ -d $path1 ] && [ -d $path2 ] || return 1;\
	    i=1; for a in $path1 $path2; do\
	      cd $a; find . -type f |\
	      cpio -o > $tmpdir/data${i} ;\
	      ((i++)); done ;\
	    for a in \\\
	      user=$user1:path=$path1:data=$tmpdir/data2 \\\
	      user=$user2:path=$path2:data=$tmpdir/data1; do\
	      eval $(echo $a | sed \"s/:/ /g\");\
	      am kill --user $user $name;\
	      pm clear --user $user $name;\
	      cd $path; cpio -i < $data;\
	      chown -R $user$uid $path;\
	    done;\
	  ) ;\
      	  stat=$?; rm -rf $tmpdir;\
	  [ $stat -eq 0 ] &&\
	    echo Success || echo Failed;\
	  ", package, source, dest, uid)

	exec(cmd)
	print ret_exec

      } else
        print "app already installed on all user: " package

      break
    }

    if( dest == "" ) {
      split(not_installed, tmparr)
      sub(/:/, "", tmparr[2])
      dest = tmparr[2]
    }

    # all set start cloning
    printf "[*] installing %s for user %d -> ",\
	package, dest
    cmd = sprintf("\
	pm install-existing --user %s %s &>/dev/null &&\
	echo Done || echo Failed;\
	", dest, package)
    exec(cmd,1)
  } while( done )
}

function installer(command,  i,a,b,c) {
  user = 0
  tmpdir = "/data/local/tmp/apk_install"
  grant_all = make_backup = keep_data = ""

  while( ARGV[++I] )
  {
    input = ARGV[I]
    if( input ~ /^-/ )
    {
	if( input == "-u" ) {
	  a = ARGV[++I]
	  b = 1
	  exec("dumpsys user")
	  for(i in SHELL)
	    if( index(SHELL[i], "UserInfo{" a":") ) {
		b = ""
		user = a; break
	    }
	  if( b ) {
	    print "UserId not available: " a
	    break
	  }
	}
	if( input == "-g" ) grant_all = input
	if( input == "-b" ) make_backup = 1
	if( input == "-k" ) keep_data = 1
	continue
    }

    if( command == "install" )
    {
      # checking file
      cmd = sprintf("\
      ls %s 2>/dev/null", input)
      exec(cmd)

      if( ret_exec ) file = ret_exec
      else {
        print "File not exist: " input
        continue
      }
    
      # start installation
      cmd = sprintf("\
        file=\"%s\" user=%s grant_all=\"%s\" \
        install_dir=%s;\
        apk=$install_dir/install.apk ;\
        mkdir -p $install_dir 2>/dev/null ;\
        printf \
        \"[==] Installing ${file##*/}  user=$user  -> \" ;\
        cp \"$file\" $apk;\
        chmod 777 $apk ;\
        pm install $grant_all \
          --user $user $apk 2>/dev/null ||\
	  echo Failed ;\
	", file, user, grant_all, tmpdir)
      exec(cmd,1)
      continue
    }

    if( command == "uninstall" )
    {
	package = input

	# Check Installed & current install status
	_get_app_info_(package)
	installed = current_installed = ""
	for(i in APP_INFO)
	  if( APP_INFO[i] ~ /installed=true/ )
	    sub(/$/, APP_INFO[i]"\n",installed)
	
	# check if package is installed
	if( installed == "" )
	{
	  print "package not installed: " package
	  continue
	}

	# check if package is installed on
	# choiced user
	current_installed = \
	  index(installed, "User " user ":")

	if( current_installed == 0 )
	{
	  print "package: " package \
	    " not installed on user: " user
	  continue
	}

	# all set.. ready for uninstalling
	if( make_backup ) {
	  repo="/sdcard/termux/etc/AppBackup/repo"
	  br_app = br_data = 1
	  _backup_(package)
	}

	if( keep_data ) {
	  printf \
	    "* Uninstalling (keep data): %s  user: %s -> ", \
	    package, user
	  cmd = sprintf("\
	    pm uninstall -k --user %s %s &>/dev/null &&\
	    echo done || echo failed \
	    ", user, package)
	  exec(cmd,1)
	  continue
	}

	printf \
	  "* Uninstalling: %s  user: %s  -> ", \
	  package, user

	cmd = sprintf("\
	user=%s package=%s ;\
	exec 2>/dev/null ;\
	am kill --user $user $package ;\
	pm clear --user $user $package ;\
	pm uninstall --user $user $package &&\
	echo done || echo failed ;\
	", user, package)
	exec(cmd)
	print ret_exec

      continue
    }
  }
  
  cmd = sprintf("a=%s;\
    [ -d $a ] && rm -r $a;", tmpdir)
  exec(cmd)
}

function _get_app_info_(package,    i) {
  split("", APP_INFO)
  exec("dumpsys package " package)
  for(i in SHELL) {
    gsub(/^[ \t]+|[ \t]+$/, "", SHELL[i])
    APP_INFO[i] = SHELL[i]
  }
}

function _backup_(package) {
  if( installed  == "" ) {
    print "App not installed: " package
    return
  }

  if( current_installed == "" ) {
    printf "package: (%s) not installed on user: %d\n",\
	   package, user
    return
  }

  # all condition meet start backup

  app_file = sprintf("%s/%s/app_.ioz",\
    repo, package)
  data_file = sprintf("%s/%s/data_%s_.ioz",\
    repo, package, user)

  printf "\n--| Backing Up %s   user:%d |--\n",\
    package, user

  while( br_app ) {
    # check exiting backup app
    cmd = sprintf("\
      ls %s 2>/dev/null;", app_file)
    exec(cmd)
    if( ret_exec ) {
	printf "    - %s\n", \
	"Backup File already exist, skip backup app"
	break
    }

    printf "    - %s -> ", "Backing up App..."
    cmd = sprintf("\
      name=%s file=%s; exec 2>/dev/null ;\
      ls -d /data/app/${name}* | while read path; do\
        cd $path;\
	ls *.apk | cpio -o | gzip > $file &&\
	echo OK || echo Failed ;\
	", package, app_file)
    exec(cmd,1)
    break
  }

  while( br_data ) {
    # data dir check
    cmd = sprintf("\
	dir=/data/user/%s/%s ;\
	ls -d $dir 2>/dev/null;\
	", user, package)
    exec(cmd)

    if( ret_exec ) data_dir = ret_exec
    else {
      printf "    - %s\n",\
	"Data Directory not found, cannot backup data"
      break
    }

    printf "    - %s -> ", "Backing up data"
    cmd = sprintf("\
	cd %s;\
	find . -type f | cpio -o | gzip > %s ;\
	[ $? -eq 0 ] && echo OK || echo Failed ;\
    ", data_dir, data_file)
    exec(cmd,1)
    break
  }
}

function _restore_(package) {
  progress = "    - %s -> "
  progress_out = "    - %s\n"

  printf "\n--| Recovering %s  user: %s |--\n",\
	 package, user

  while( br_app ) {
    if( installed ) {
      if( current_installed ) {
	printf progress_out,\
	  "app already installed, skip installing"
      }
      else {
	printf progress_out,\
	  "app already installed on another user"
        printf progress, "Cloning app"
	cmd = sprintf("pm install-existing --user %s %s",\
	    user, package)
	exec(cmd)
	sub(/.*/, "OK", ret_exec)
	print ret_exec
	current_installed = 1
      }
      break
    }
    
    # check backup app
    cmd = sprintf("\
        ls %s/%s/app_.ioz 2>/dev/null; \
      ", repo, package)
      exec(cmd)
      if( ret_exec ) file = ret_exec
      else {
	printf progress_out, "Backup file not found"
	printf progress_out, "Cannot restore app or data"
	break
      }

      printf progress, "Restoring App"
      cmd = sprintf("\
	user=%s file=%s package=%s;\
	tmpdir=/data/local/tmp/AppBackup ;\
	exec 2>/dev/null ;\
	mkdir -p $tmpdir ;\
        zcat $file | ( \
	  cd $tmpdir; cpio -i ;\
	  chmod 777 ./*.apk;\
	  pm install --user $user base.apk >/dev/null &&\
	  return 0 ||\
	  split=$(ls *.apk | sed \"/base.apk/ d\");\
	  pm install --user $user \
	  -p base.apk $split >/dev/null ;\
	  ) ;\
	[ $? -eq 0 ] && echo OK || echo Failed ;\
	rm -r $tmpdir;\
	", user, file, package)
      exec(cmd,1)

      # Update app info
      _get_app_info_(package)
      current_installed = 1
      break
    }

    while( br_data ) {
	if( current_installed == "" ) {
	  printf progress_out,\
	    "App not installed, cannot restore data"
	  break
	}
	# check backup file
	cmd = sprintf("\
	ls %s/%s/data_%s_.ioz 2>/dev/null;\
	", repo, package, user)
	exec(cmd)

	if( ret_exec ) data_file = ret_exec
	else {
	  printf progress_out, "Backup data file not found"
	  printf progress_out, "Recover data: failed"
	  break
        }

	# get uid
	for(a in APP_INFO) \
	    if( APP_INFO[a] ~ /userId=/ ) {
		uid = APP_INFO[a]
		sub(/^.*=/, user, uid)
	    }

	printf progress, "Restoring data"
	cmd = sprintf("\
	package=%s user=%d file=%s;\
  	path=/data/user/$user/$package ;\
	am kill --user $user $package &>/dev/null;\
	pm clear --user $user $package &>/dev/null;\
	[ -d $path ] || mkdir -p $path;\
	zcat $file | ( cd $path; cpio -i; ) &&\
	  echo OK || echo failed ;\
	", package, user, data_file)
	exec(cmd,1)


	printf progress, "Setting Permissions"
	cmd = sprintf("\
	chown -R %d /data/user/%s/%s &&\
	echo OK || echo Failed ;\
	    ", uid, user, package)
	exec(cmd,1)
	break
    }
}

function misc(command)
{
  user = 0
  while( ARGV[++I] ) {
    if( ARGV[I] == "-u" )
      { user = ARGV[++I]; continue; }
    if( command == "mask" )
      { _hider_(ARGV[I],user); continue; }
  }
}

function _hider_(package,user)
{
  do {
    if(package == "") break
    if(user == "") user = 0

    _get_app_info_(package)
    installed = ""
    for(i in APP_INFO) {
	if( APP_INFO[i] ~ /installed=true/ )
	  sub(/$/, APP_INFO[i]"\n", installed)
    }

    if( installed == "" ) {
	print "App not installed: " package
	break
    }


    dex = index(installed, "User " user ":")
    if(dex == 0) {
	print "App: " package " not installed on user:" user
	break
    }

    len = length(installed)
    a = substr(installed, dex, 10)
    print a

  } while(0)
}

BEGIN {
# Init Block

# Input Processing
  while( ARGV[++I] ) {
    if( ARGV[I] == "--help" )
	{ show_help(ARGV[++I]); break; }
    if( ARGV[I] ~ /^(un)?install$/ )
      	{ installer(ARGV[I]); continue; }
    if( ARGV[I] ~ /backup|restore/ )
      	{ backup_restore(ARGV[I]); continue; }
    if( ARGV[I] == "clone" )
	{ app_cloner(); continue; }
    if( ARGV[I] == "mask" )
	{ misc(ARGV[I]); continue; }
  }

# End Block
  exit
}
' "$@"
