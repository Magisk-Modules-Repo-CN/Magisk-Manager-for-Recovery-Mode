#!/sbin/sh
# Magisk Manager for Recovery Mode (mm)
# VR25 @ xda-developers

# Detect whether in boot mode
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true || BOOTMODE=false
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
$BOOTMODE || id | grep -q 'uid=0' || BOOTMODE=true

# Exit script if running in boot mode
if $BOOTMODE; then
	echo -e "- 这仅适用于Recovery模式\n"
	exit 1
fi

# Default permissions
umask 022

##########################################################################################
# Functions
##########################################################################################

is_mounted() { mountpoint -q "$1"; }

mount_image() {
  e2fsck -fy $IMG &>/dev/null
  if [ ! -d "$2" ]; then
    mount -o remount,rw /
    mkdir -p "$2"
  fi
  if (! is_mounted $2); then
    LOOPDEVICE=
    for LOOP in 0 1 2 3 4 5 6 7; do
      if (! is_mounted $2); then
        LOOPDEVICE=/dev/block/loop$LOOP
        [ -f "$LOOPDEVICE" ] || mknod $LOOPDEVICE b 7 $LOOP 2>/dev/null
        losetup $LOOPDEVICE $1
        if [ "$?" -eq "0" ]; then
          mount -t ext4 -o loop $LOOPDEVICE $2
          is_mounted $2 || /system/bin/toolbox mount -t ext4 -o loop $LOOPDEVICE $2
          is_mounted $2 || /system/bin/toybox mount -t ext4 -o loop $LOOPDEVICE $2
        fi
        is_mounted $2 && break
      fi
    done
  fi
  if ! is_mounted $MOUNTPATH; then
    echo -e "\n(!) $IMG 挂载失败... 终止\n"
    exit 1
  fi
}

set_perm() {
  chown $2:$3 "$1" || exit 1
  chmod $4 "$1" || exit 1
  [ -z "$5" ] && chcon 'u:object_r:system_file:s0' "$1" || chcon $5 "$1"
}

set_perm_recursive() {
  find "$1" -type d 2>/dev/null | while read dir; do
	set_perm "$dir" $2 $3 $4 $6
  done
  find "$1" -type f -o -type l 2>/dev/null | while read file; do
	set_perm "$file" $2 $3 $5 $6
  done
}

Actions() {
	echo
	cat <<EOD
e) 启用/禁用模块
l) 列出安装的模块
m) 让 magisk.img 进入生存模式(在恢复出厂设置后保留模块)
r) 更改 magisk.img 的大小
s) 更改 Magisk 设置 (使用vi编辑器)
t) 切换自动挂载
u) 卸载模块
---
x. 退出
EOD
	read Input
	echo
}

exit_or_not() {
	echo -e "\n(i) 你还想做其他事吗? (Y/n)"
	read Ans
	echo $Ans | grep -iq n && echo && exxit || Opts
}

mod_ls() { ls -1 $MOUNTPATH | grep -v 'lost+found'; }


Toggle() {
	echo "<切换 $1>" 
	: > $tmpf
	: > $tmpf2
	Input=0
	
	for mod in $(mod_ls); do
		if $auto_mount; then
			[ -f "$mod/$2" ] && echo "$mod (启用)" >> $tmpf \
				|| echo "$mod (禁用)" >> $tmpf
		else
			[ -f "$mod/$2" ] && echo "$mod (禁用)" >> $tmpf \
				|| echo "$mod (启用)" >> $tmpf
		fi
	done
	
	echo
	cat $tmpf
	echo
	
	echo "(i) 输入模块id"
	echo "- 当输入完成时按下[ENTER]; 按下 [CTRL]+C 退出"

	until [ -z "$Input" ]; do
		read Input
		if [ "$Input" ]; then
			grep "$Input" $tmpf | grep -q '(启用)' && \
				echo "$3 $(grep "$Input" $tmpf | grep '(启用)')/$2" >> $tmpf2
			grep "$Input" $tmpf | grep -q '(禁用)' && \
				echo "$4 $(grep "$Input" $tmpf | grep '(禁用)')/$2" >> $tmpf2
		fi
	done
	
	cat $tmpf2 | sed 's/ (启用)//' | sed 's/ (禁用)//' > $tmpf
	
	if grep -Eq '[0-9]|[a-z]|[A-Z]' $tmpf; then
		. $tmpf
		echo "结果:"
		
		grep -q '(启用)' $tmpf2 && cat $tmpf2 \
			| sed 's/(启用)/(启用) --> (禁用)/' \
			| sed "s/$3 //" | sed "s/$4 //" | sed "s/\/$2//"
		grep -q '(禁用)' $tmpf2 && cat $tmpf2 \
			| sed 's/(禁用)/(禁用) --> (启用)/' \
			| sed "s/$3 //" | sed "s/$4 //" | sed "s/\/$2//"
	
	else
		echo "(i) 操作终止: 无输入或输入错误"
	fi
}


auto_mnt() { auto_mount=true; Toggle auto_mount auto_mount rm touch; }

enable_disable_mods() { auto_mount=false; Toggle "模块 启用/禁用" disable touch rm; }

exxit() {
	cd $TmpDir
	umount $MOUNTPATH
	losetup -d $LOOPDEVICE
	rmdir $MOUNTPATH
	[ "$1" != "1" ] && exec echo -e "再见.\n" || exit 1
}

list_mods() {
	echo -e "<已安装模块列表>\n"
	for mods in $(mod_ls); do
		source $MOUNTPATH/$mods/module.prop
		echo "$id ($name)"
	done
}


Opts() {
	echo -e "\n(i) 选择一个选项..."
	Actions

	case "$Input" in
		e ) enable_disable_mods;;
		l ) list_mods;;
		m ) immortal_m;;
		r ) resize_img;;
		s ) m_settings;;
		t ) auto_mnt;;
		u ) rm_mods;;
		x ) exxit;;
		* ) Opts;;
	esac
	
	exit_or_not
}


resize_img() {
	echo -e "<更改 magisk.img 的大小>\n"
	cd $TmpDir
	df -h $MOUNTPATH
	umount $MOUNTPATH
	losetup -d $LOOPDEVICE
	echo -e "\n(i) 输入您想更改的大小 单位为MB 然后按下[ENTER]"
	echo "- 或者不输入任何东西, 直接按下[ENTER] 来回到主菜单"
	echo "- 按下 [CTRL]+C 退出"
	read Input
	if [ -n "$Input" ]; then
		echo
		resize2fs $IMG ${Input}M
	else
		echo "(i) 操作终止: 无输入或输入错误"
	fi
	mount_image $IMG $MOUNTPATH
	cd $MOUNTPATH
}


rm_mods() { 
	: > $tmpf
	: > $tmpf2
	Input=0
	list_mods
	echo
	echo "(i) 输入模块id"
	echo "- 当输入完成时按下[ENTER]; 按下 [CTRL]+C 退出"

	until [ -z "$Input" ]; do
		read Input
		[ "$Input" ] && mod_ls | grep "$Input" \
			| sed 's/^/rm -rf /' >> $tmpf \
			&& mod_ls | grep "$Input" >> $tmpf2
	done

	if grep -Eq '[0-9]|[a-z]|[A-Z]' $tmpf; then
		. $tmpf
		echo "被删除的模块:"
		cat $tmpf2
	else
		echo "(i) 操作终止: 无输入或输入错误"
	fi
}


immortal_m() {
	F2FS_workaround=false
	if ls /cache | grep -i magisk | grep -iq img; then
		echo "(i) 在 /cache 找到了 magisk 镜像文件"
		echo "- 您正在使用f2fs文件系统作为错误缓存解决方案吗? (y/N)"
		read F2FS_workaround
		echo
		case $F2FS_workaround in
			[Yy]* ) F2FS_workaround=true;;
			* ) F2FS_workaround=false;;
		esac
		
		$F2FS_workaround && echo "(!) 这个选项并不适合你"
	fi
	
	if ! $F2FS_workaround; then
		if [ ! -f /data/media/magisk.img ] && [ -f "$IMG" ] && [ ! -h "$IMG" ]; then
			Err() { echo "$1"; exit_or_not; }
			echo "(i) 移动 $IMG 到 /data/media"
			mv $IMG /data/media \
				&& echo "-> ln -s /data/media/magisk.img $IMG" \
				&& ln -s /data/media/magisk.img $IMG \
				&& echo -e "- 一切就绪.\n" \
				&& echo "(i) 在恢复出厂设置后再次执行这个操作来创建软链接" \
				|| Err "- (!) $IMG 无法被移动"
			
		else
			if [ ! -e "$IMG" ]; then
				echo "(i) Fresh ROM, uh?"
				echo "-> ln -s /data/media/magisk.img $IMG"
				ln -s /data/media/magisk.img $IMG \
				&& echo "- 重新创建软链接成功" \
				&& echo "- 一切就绪" \
				|| echo -e "\n(!) 软链接创建失败"
			else
				echo -e "(!) $IMG 已存在 -- 不能创建软链接"
			fi
		fi
	fi
}


m_settings() {
	echo "(!) 警告:这个选项具有潜在的危险"
	echo "- 仅限高级用户使用"
	echo "- 是否继续? (y/N)"
	read Ans

	if echo "$Ans" | grep -i y; then
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
		read
		vi /data/data/com.topjohnwu.magisk/shared_prefs/com.topjohnwu.magisk_preferences.xml
	fi
}
##########################################################################################
# Environment
##########################################################################################

TmpDir=/dev/mm_tmp
tmpf=$TmpDir/tmpf
tmpf2=$TmpDir/tmpf2
MOUNTPATH=/magisk

mount /data 2>/dev/null
mount /cache 2>/dev/null

[ -d /data/adb/magisk ] && IMG=/data/adb/magisk.img || IMG=/data/magisk.img

if [ ! -d /data/adb/magisk ] && [ ! -d /data/magisk ]; then
	echo -e "\n(!) 找不到安装的Magisk或者安装的Magisk版本不被支持\n"
	exit 1
fi

mkdir -p $TmpDir 2>/dev/null
mount_image $IMG $MOUNTPATH
cd $MOUNTPATH

echo -e "\nRecovery下的Magisk管理器 (mm)"
echo "- VR25 @ xda-developers ; cjybyjk @ coolapk"
echo -e "- Powered by Magisk (@topjohnwu)\n"
Opts
