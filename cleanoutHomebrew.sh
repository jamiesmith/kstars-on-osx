#/bin/bash
echo "This will remove all homebrew programes and their cached installers"
read -p "Are you ready to proceed (y/n)? " proceed

if [ "$proceed" != "y" ]
then
	exit
fi

#Cleanout homebrew
brew remove --force $(brew list) --ignore-dependencies

#Remove cache files
brew cleanup