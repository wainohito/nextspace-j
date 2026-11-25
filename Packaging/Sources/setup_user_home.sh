#!/bin/sh

echo "Copying initial settings from $PWD/home"
if [ -d "$HOME/Library" ];then
	# ~/Library may already exist only because GNUstep tools ran (e.g. while
	# building): add the missing default settings, keep existing files.
	echo "$HOME/Library exists already: adding missing default settings only"
	cp -Rn /etc/skel/Library/. "$HOME/Library/"
else
	cp -R /etc/skel/Library $HOME/
fi

cp -Rn /etc/skel/.config $HOME/

if [ -f "$HOME/.xinitrc" ];then
	echo "$HOME/.xinitrc exists already, will not overwrite!"
else
	cp ./extra/xinitrc $HOME/.xinitrc
fi
