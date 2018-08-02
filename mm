#!/sbin/sh
# (c) 2017-2018, VR25 @ xda-developers ; cjybyjk @ coolapk
# License: GPL v3+

# language select
CHINESE=false
ON="(ON)"
OFF="(OFF)"
zh_prop="$(getprop persist.sys.locale) $(getprop persist.sys.language)"
if [ -f "/twres/languages/zh_CN.xml" ] || [ -f "/twres/languages/zh_TW.xml" ] || \
	[ "$(echo $zh_prop | grep zh)" != "" ]; then
	CHINESE=true
	ON="(启用)"
	OFF="(禁用)"
fi

# detect whether in boot mode
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true || BOOTMODE=false
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
$BOOTMODE || id | grep -q 'uid=0' || BOOTMODE=true

# exit if running in boot mode
if $BOOTMODE; then
	if $CHINESE; then
		echo -e "- 这仅适用于Recovery模式\n"
	else
		echo -e "\nI saw what you did there... :)"
		echo "- Bad idea!"
		echo -e "- This is meant to be used in recovery mode only.\n"
	fi
	exit 1
fi

# Default permissions
umask 022

is_mounted() { mountpoint -q "$1"; }

mount_image() {
  e2fsck -fy $IMG &>/dev/null
  if [ ! -d "$2" ]; then
    mount -o remount,rw /
    mkdir -p "$2"
  fi
  if (! is_mounted $2); then
    loopDevice=
    for LOOP in 0 1 2 3 4 5 6 7; do
      if (! is_mounted $2); then
        loopDevice=/dev/block/loop$LOOP
        [ -f "$loopDevice" ] || mknod $loopDevice b 7 $LOOP 2>/dev/null
        losetup $loopDevice $1
        if [ "$?" -eq "0" ]; then
          mount -t ext4 -o loop $loopDevice $2
          is_mounted $2 || /system/bin/toolbox mount -t ext4 -o loop $loopDevice $2
          is_mounted $2 || /system/bin/toybox mount -t ext4 -o loop $loopDevice $2
        fi
        is_mounted $2 && break
      fi
    done
  fi
  if ! is_mounted $mountPath; then
    $CHINESE && echo -e "\n(!) $IMG 挂载失败... 终止\n" || echo -e "\n(!) $IMG mount failed... abort\n"
    exit 1
  fi
}



actions() {
	echo
	if $CHINESE; then
	cat <<EOD
e) 启用/禁用模块
l) 列出安装的模块
m) 让 magisk.img 进入生存模式(在恢复出厂设置后保留模块)
r) 改变 magisk.img 的大小
s) 更改 Magisk 设置 (使用vi编辑器)
t) 切换自动挂载
u) 卸载模块
---
x. 退出
EOD
	else
		cat <<EOD
e) Enable/disable modules
l) List installed modules
m) Make magisk.img survive f. resets
r) Resize magisk.img
s) Change Magisk settings (using vi text editor)
t) Toggle auto_mount
u) Uninstall modules
---
x. Exit
EOD
	fi
	read Input
	echo
}

exit_or_not() {
	$CHINESE && echo -e "\n(i) 你还想做其他事吗? (Y/n)" || echo -e "\n(i) Would you like to do anything else? (Y/n)"
	read Ans
	echo $Ans | grep -iq n && echo && exxit || opts
}

ls_mount_path() { ls -1 $mountPath | grep -v 'lost+found'; }


toggle() {
	$CHINESE && echo "<切换 $1>" || echo "<Toggle $1>" 
	: > $tmpf
	: > $tmpf2
	Input=0
	
	for mod in $(ls_mount_path); do
		if $auto_mount; then
			[ -f "$mod/$2" ] && echo "$mod $ON" >> $tmpf \
				|| echo "$mod $OFF" >> $tmpf
		else
			[ -f "$mod/$2" ] && echo "$mod $OFF" >> $tmpf \
				|| echo "$mod $ON" >> $tmpf
		fi
	done
	
	echo
	cat $tmpf
	echo
	if $CHINESE; then
	echo "(i) 输入模块id的前几个字符或者全部字符"
	echo "- 当输入完成时按两次[ENTER]; 按下 [CTRL]+C 退出"
	else
		echo "(i) Input a matching WORD/string at once"
		echo "- Press ENTER twice when done; CTRL+C to exit"
	fi
	until [ -z "$Input" ]; do
		read Input
		if [ -n "$Input" ]; then
			grep "$Input" $tmpf | grep -q "$ON" && \
				echo "$3 $(grep "$Input" $tmpf | grep "$ON")/$2" >> $tmpf2
			grep "$Input" $tmpf | grep -q "$OFF" && \
				echo "$4 $(grep "$Input" $tmpf | grep "$OFF")/$2" >> $tmpf2
		fi
	done
	
	cat $tmpf2 | sed 's/ $ON//' | sed 's/ $OFF//' > $tmpf
	
	if grep -Eq '[0-9]|[a-z]|[A-Z]' $tmpf; then
		. $tmpf
		$CHINESE && echo "结果:" || echo "Result(s):"
		
		grep -q "$ON" $tmpf2 && cat $tmpf2 \
			| sed "s/$ON/$ON --> $OFF/" \
			| sed "s/$3 //" | sed "s/$4 //" | sed "s/\/$2//"
		grep -q "$OFF" $tmpf2 && cat $tmpf2 \
			| sed "s/$OFF/$OFF --> $ON/" \
			| sed "s/$3 //" | sed "s/$4 //" | sed "s/\/$2//"
	
	else
		$CHINESE && echo "(i) 操作终止: 无输入或输入错误" || echo "(i) Operation aborted: null/invalid input"
	fi
}


auto_mnt() { auto_mount=true; toggle auto_mount auto_mount rm touch; }

enable_disable_mods() { 
	auto_mount=false
	$CHINESE && toggle "模块 启用/禁用" disable touch rm || toggle "Module ON/OFF" disable touch rm
}

exxit() {
	cd $tmpDir
	umount $mountPath
	losetup -d $loopDevice
	rmdir $mountPath
	[ "$1" != "1" ] && ($CHINESE && echo -e "再见.\n" || echo -e "Goodbye.\n") && exit 0 || exit 1
}

list_mods() {
	$CHINESE && echo -e "<已安装模块列表>\n" || echo -e "<Installed Modules>\n"
	for mods in $(ls_mount_path); do
		modid=`sed '/^id=/!d;s/.*=//' $mountPath/$mods/module.prop`    
		modname=`sed '/^name=/!d;s/.*=//' $mountPath/$mods/module.prop`  
		echo "$modid ($modname)"
	done
}

opts() {
	$CHINESE && echo -e "\n(i) 选择一个选项..." || echo -e "\n(i) Pick an option..."
	actions

	case "$Input" in
		e ) enable_disable_mods;;
		l ) list_mods;;
		m ) immortal_m;;
		r ) resize_img;;
		s ) m_settings;;
		t ) auto_mnt;;
		u ) rm_mods;;
		x ) exxit;;
		* ) opts;;
	esac
	
	exit_or_not
}


resize_img() {
	$CHINESE && echo -e "<改变 magisk.img 的大小>\n" || echo -e "<Resize magisk.img>\n"
	cd $tmpDir
	df -h $mountPath
	umount $mountPath
	losetup -d $loopDevice
	if $CHINESE; then
	echo -e "\n(i) 输入您想更改的大小 单位为MB 然后按下[ENTER]"
	echo "- 或者不输入任何东西, 直接按下[ENTER] 来回到主菜单"
	else
		echo -e "\n(i) Input the desired size in MB"
		echo "- Or nothing to cancel"
	fi
	read Input
	[ -n "$Input" ] && echo -e "\n$(resize2fs $IMG ${Input}M)" \
    || ($CHINESE && echo -e "\n(!) 操作终止: 无输入或输入错误" || echo -e "\n(!) Operation aborted: null/invalid input")
	mount_image $IMG $mountPath
	cd $mountPath
}


rm_mods() { 
	: > $tmpf
	: > $tmpf2
	Input=0
	list_mods
	if $CHINESE; then
	echo -e "\n(i) 输入模块id的前几个字符或者全部字符"
	echo "- 当输入完成时按两次[ENTER]; 按下 [CTRL]+C 退出"
	else
		echo -e "\n(i) Input a matching WORD/string at once"
		echo "- Press ENTER twice when done, CTRL+C to exit"
	fi
	until [ -z "$Input" ]; do
		read Input
		[ -n "$Input" ] && ls_mount_path | grep "$Input" \
			| sed 's/^/rm -rf /' >> $tmpf \
			&& ls_mount_path | grep "$Input" >> $tmpf2
	done

	if grep -Eq '[0-9]|[a-z]|[A-Z]' $tmpf; then
		. $tmpf
		$CHINESE && echo "被删除的模块:" || echo "Removed Module(s):"
		cat $tmpf2
	else
		$CHINESE && echo "(!) 操作终止: 无输入或输入错误" || echo "(!) Operation aborted: null/invalid input"
	fi
}


immortal_m() {
	F2FS_workaround=false
	if ls /cache | grep -i magisk | grep -iq img; then
		if $CHINESE; then
		echo "(i) 在 /cache 找到了 magisk 镜像文件"
		echo "- 您正在使用f2fs文件系统作为错误缓存解决方案吗? (y/N)"
		else
			echo "(i) A Magisk image file has been found in /cache"
			echo "- Are you using the F2FS bug cache workaround? (y/N)"
		fi
		read F2FS_workaround
		echo
		case $F2FS_workaround in
			[Yy]* ) F2FS_workaround=true;;
			* ) F2FS_workaround=false;;
		esac
		
		$F2FS_workaround && ($CHINESE && echo "(!) 这个选项并不适合你" || echo "(!) This option is not for you then")
	fi
	
	if ! $F2FS_workaround; then
		if [ ! -f /data/media/magisk.img ] && [ -f "$IMG" ] && [ ! -h "$IMG" ]; then
			Err() { echo "$1"; exit_or_not; }
			$CHINESE && echo "(i) 移动 $IMG 到 /data/media" || echo "(i) Moving $IMG to /data/media"
			mv $IMG /data/media \
				&& echo "-> ln -s /data/media/magisk.img $IMG" \
				&& ln -s /data/media/magisk.img $IMG \
				&& ($CHINESE && echo -e "- 一切就绪.\n" || echo -e "- All set.\n") \
				&& ($CHINESE && echo "(i) 在恢复出厂设置后再次执行这个操作来创建软链接" || echo "(i) Run this again after a factory reset to recreate the symlink.") \
				|| ($CHINESE && Err "- (!) $IMG 无法被移动" || Err "- (!) $IMG couldn't be moved")
			
		else
			if [ ! -e "$IMG" ]; then
				echo "(i) Fresh ROM, uh?"
				echo "-> ln -s /data/media/magisk.img $IMG"
				ln -s /data/media/magisk.img $IMG \
          && ($CHINESE && echo "- 重新创建软链接成功" || echo "- Symlink recreated successfully") \
          && ($CHINESE && echo "- 一切就绪" || echo "- You're all set") \
          || ($CHINESE && echo -e "\n(!) 软链接创建失败" || echo -e "\n(!) Symlink creation failed")
			else
				$CHINESE && echo -e "(!) $IMG 已存在 -- 不能创建软链接" || echo -e "(!) $IMG exists -- symlink cannot be created"
			fi
		fi
	fi
}


m_settings() {
	if $CHINESE; then
		echo "(!) 警告:这个选项具有潜在的危险"
		echo "- 仅限高级用户使用"
		echo "- 是否继续? (y/N)"
	else
		echo "(!) Warning: potentially dangerous section"
		echo "- For advanced users only"
		echo "- Proceed? (y/N)"
	fi
	read Ans

	if echo "$Ans" | grep -i y; then
		if $CHINESE; then
			cat <<EOD

一些vi编辑器的基本用法

i --> 进入输入模式

[Esc] --> 回到命令模式
ZZ --> 保存更改并退出
:q! [ENTER] --> 撤销更改并退出
/STRING --> 将光标移动到第一个匹配STRING的位置
n --> 将光标移动到下一个匹配STRING的位置

按下回车键继续...
EOD
		else
			cat <<EOD

Some Basic vi Usage

i --> enable insertion/typing mode

esc key --> return to comand mode
ZZ --> save changes & exit
:q! ENTER --> discard changes & exit
/STRING --> go to STRING


Note that I'm no vi expert by any meAns, but the above should suffice.

Hit ENTER to continue...
EOD
		fi
		read
		vi /data/data/com.topjohnwu.magisk/shared_prefs/com.topjohnwu.magisk_preferences.xml
	fi
}



tmpDir=/dev/mm_tmp
tmpf=$tmpDir/tmpf
tmpf2=$tmpDir/tmpf2
mountPath=/magisk

mount /data 2>/dev/null
mount /cache 2>/dev/null

[ -d /data/adb/magisk ] && IMG=/data/adb/magisk.img || IMG=/data/magisk.img

if [ ! -d /data/adb/magisk ] && [ ! -d /data/magisk ]; then
	$CHINESE && echo -e "\n(!) 找不到安装的Magisk或者安装的Magisk版本不被支持\n" || echo -e "\n(!) No Magisk installation found or installed version is not supported\n"
	exit 1
fi

mkdir -p $tmpDir 2>/dev/null
mount_image $IMG $mountPath
cd $mountPath

$CHINESE && echo -e "\nRecovery下的Magisk管理器 (mm)
(c) 2017-2018, VR25 @ xda-developers ; cjybyjk @ coolapk
License: GPL v3+" || \
echo -e "\nMagisk Manager for Recovery Mode (mm)
(c) 2017-2018, VR25 @ xda-developers ; cjybyjk @ coolapk
License: GPL v3+"

opts
