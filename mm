#!/sbin/sh
# (c) 2017-2018, VR25 @ xda-developers
# translator: cjybyjk @ coolapk
# License: GPL v3+

# detect whether in boot mode
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true || BOOTMODE=false
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
$BOOTMODE || id | grep -q 'uid=0' || BOOTMODE=true

# exit if running in boot mode
if $BOOTMODE; then
	echo -e "\n我知道你想干啥... :)"
	echo "- 这是个坏主意! "
	echo -e "- 仅供在recovery模式下使用\n"
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
    echo -e "\n(!) $IMG 挂载失败... 终止\n"
    exit 1
  fi
}



actions() {
	echo
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
	read Input
	echo
}

exit_or_not() {
	echo -e "\n(i) 你还想继续进行其他操作吗? (Y/n)"
	read Ans
	echo $Ans | grep -iq n && echo && exxit || opts
}

ls_mount_path() { ls -1 $mountPath | grep -v 'lost+found'; }


toggle() {
	echo "<切换 $1>"
	: > $tmpf
	: > $tmpf2
	Input=0
	
	for mod in $(ls_mount_path); do
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

	echo "(i) 输入模块id的部分字符或者全部字符"
	echo "- 示例:id为brevent_boot，输入boot或者brevent即可"
	echo "- 当输入完成时按两次[ENTER]; 按下 [CTRL]+C 退出"

	until [ -z "$Input" ]; do
		read Input
		if [ -n "$Input" ]; then
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


auto_mnt() { auto_mount=true; toggle auto_mount auto_mount rm touch; }

enable_disable_mods() { auto_mount=false; toggle "模块 启用/禁用" disable touch rm; }

exxit() {
	cd $tmpDir
	umount $mountPath
	losetup -d $loopDevice
	rmdir $mountPath
	[ "$1" != "1" ] && echo -e "再见~\n" || exit 1
}

list_mods() {
	echo -e "<已安装模块列表>\n"
	for mods in $(ls_mount_path); do 
		modname=`cat $mountPath/$mods/module.prop | grep '^name' | awk -F'=' '{ print $2 }' `
		echo "$mods ($modname)"
	done
}

opts() {
	echo -e "\n(i) 选择一个选项..."
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
	echo -e "<改变 magisk.img 的大小>\n"
	cd $tmpDir
	df -h $mountPath
	umount $mountPath
	losetup -d $loopDevice
	echo -e "\n(i) 以MB为单位输入所需大小 然后按下[ENTER]"
	echo "- 或者不输入任何东西, 直接按下[ENTER] 来回到主菜单"
	read Input
	[ -n "$Input" ] && echo -e "\n$(resize2fs $IMG ${Input}M)" \
    || echo -e "\n(!) 操作终止: 无输入或输入错误"
	mount_image $IMG $mountPath
	cd $mountPath
}


rm_mods() { 
	: > $tmpf
	: > $tmpf2
	Input=0
	list_mods

	echo "(i) 输入模块id的部分字符或者全部字符"
	echo "- 示例:id为brevent_boot，输入boot或者brevent即可"
	echo "- 当输入完成时按两次[ENTER]; 按下 [CTRL]+C 退出"

	until [ -z "$Input" ]; do
		read Input
		[ -n "$Input" ] && ls_mount_path | grep "$Input" \
			| sed 's/^/rm -rf /' >> $tmpf \
			&& ls_mount_path | grep "$Input" >> $tmpf2
	done

	if grep -Eq '[0-9]|[a-z]|[A-Z]' $tmpf; then
		. $tmpf
		echo "已移除模块:"
		cat $tmpf2
	else
		echo "(!) 操作终止: 无输入或输入错误"
	fi
}


immortal_m() {
	F2FS_workaround=false
	if ls /cache | grep -i magisk | grep -iq img; then
		echo "(i) 在 /cache 找到了 magisk 镜像文件"
		echo "- 您正在使用F2FS bug cache workaround吗? (y/N)"
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
				&& echo "(i) 在恢复出厂设置后再次运行此项以重新创建符号链接"  \
				|| Err "- (!) $IMG 无法被移动"
			
		else
			if [ ! -e "$IMG" ]; then
				echo "(i) 干净的ROM, 嗯?"
				echo "-> ln -s /data/media/magisk.img $IMG"
				ln -s /data/media/magisk.img $IMG \
          && echo "- 重新创建符号链接成功" \
          && echo "- 一切就绪" \
          || echo -e "\n(!) 符号链接创建失败"
			else
				echo -e "(!) $IMG 已存在 -- 不能创建符号链接"
			fi
		fi
	fi
}


m_settings() {
	echo "(!) 警告: 接下来的操作可能存在危险"
	echo "- 仅限专业用户操作"
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

按下[ENTER]继续...
EOD

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
	echo -e "\n(!) 找不到安装的Magisk或者安装的Magisk版本不被支持\n"
	exit 1
fi

mkdir -p $tmpDir 2>/dev/null
mount_image $IMG $mountPath
cd $mountPath

echo -e "\nRecovery下的Magisk管理器 (mm)
(c) 2017-2018, VR25 @ xda-developers ; cjybyjk @ coolapk
License: GPL v3+" 

opts
