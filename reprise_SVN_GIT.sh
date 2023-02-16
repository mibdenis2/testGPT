#!/bin/bash

#===================
# Variables globales

# Nom du répertoire parent
HOME_PROJECT=$(dirname ${PWD})
# Nom du répertoire git local
LOCAL_PROJECT=$HOME_PROJECT/LOCAL
# Nom du fichier csv listant les projets svn
SVN_PROJECTS_CONF_FILE=$HOME_PROJECT/file/config_repo.csv
#===================
#=================================================
# Fonction qui adapte à GIT une branche SVN migrée
adaptBranchToGIT()
{
	if [[ $1 != "HEAD" ]]; then
		git checkout $1
		if [ -e pom.xml ]; then
			echo "=== Adaptations post-migration de la branche '"$1"'==="
			echo "=== Adaptation du connecteur SCM du pom.xml ==="
			sed -i 's/\(<connection>\).*\(<\/connection>\)/<connection>'$2'<\/connection>/' pom.xml
			echo "=== Ajout du fichier .gitignore ==="
			cp $HOME_PROJECT/file/.gitignore $LOCAL_PROJECT/$git_repo_name
			git add .gitignore
			message="SCM::Post-migration GIT - Adaptation du connecteur SCM et ajout du fichier .gitignore sur la branche "$1
			git commit -a -m$message
		fi
	fi
}
#=================================================

echo "================================================"
echo "=== Reprise SVN GIT : Démarrage du processus ==="
echo "================================================"
echo "=== "`date +"%Y-%m-%d %T"`" ==="

if [[ ! -d $LOCAL_PROJECT ]]; then
	mkdir $LOCAL_PROJECT
	echo "Création du répertoire "$LOCAL_PROJECT
fi

IFS=";"
#####################################################################
# Pour un layout non standard : Trunk, Branches de releases et tags #
# Pour un layout standard : on traite tout                          #
#####################################################################
while read to_migrate svn_repo_URL git_project_code git_repo_name git_repo_label svn_stdandard_migration svn_customers_rootDir svn_features_rootDir svn_releases_rootDir svn_tags_rootDir svn_trunk_rootDir emptyParam
do 
	if [[ $to_migrate == "1" ]]; then
		repo="ssh://git@hra-bitbucket.ptx.fr.sopra:7999/"$git_project_code/$git_repo_name".git"
		connector='scm:git:\${git.base.url}\/scm\/'$git_project_code'\/'$git_repo_name
		# On commence par supprimer le dépôt local GIT
		cd $LOCAL_PROJECT
		rm -R -f $git_repo_name
		echo "=== Migration du projet svn "$svn_repo_URL" ==="
		###################################################
		# Détermination du repo svn à partir de l'url SVN #
		###################################################
		# par exemple : svn_repo_URL = https://svn.ptx.fr.sopra/svnhra/hrdc/HRD%20Policy%20Lines/7.xx/Webtools
		pos=`expr index $svn_repo_URL /` # par exemple : pos = 7
		string=${svn_repo_URL:pos+1} # par exemple : string = svn.ptx.fr.sopra/svnhra/hrdc/HRD%20Policy%20Lines/7.xx/Webtools
		pos=`expr index $string /` # par exemple : pos = 17
		string=${string:pos} # par exemple : string = svnhra/hrdc/HRD%20Policy%20Lines/7.xx/Webtools
		pos=`expr index $string /` # par exemple : pos = 7
		string=${string:pos} # par exemple : string = hrdc/HRD%20Policy%20Lines/7.xx/Webtools
		pos=`expr index $string /` # par exemple : pos = 5
		svn_repo_name=${string:0:pos-1} # par exemple : svn_repo_name = hrdc
		##########################################################
		# Fin de détermination du repo svn à partir de l'url SVN #
		##########################################################
		
		# Pour une migration standard (avec répertoire 'branches', 'tags' et 'trunk', et reprise de toutes les branches et tous les tags) utiliser l'option --stdlayout
		# Pour une migration personnalisée :
		# - avec des sous-répertoires 'Customers', 'Features' et 'Releases' sous 'branches', 
		# - et/ou sur lequel on souhaite reprendre une sous partie des branches et des tags 
		#    (par exemple filtrer sur les branches et tags qui ne sont plus utilisés, et/ou filtrer les branches et tags qui ont été supprimées dans SVN)
		# on ajoute chaque sous-répertoire à l'aide du paramètre --branches
		# Par exemple :
		#	--branches=branches/Customers --branches=branches/Features --branches=branches/Releases --branches=tags/Releases"
		# NB : --trunk, --branches, et --tags ne peuvent pas être utilisés en surcharge de --stdlayout, ils sont exclusifs
		# Pour les tags, on a besoin de les modifier (modification du connecteur SCM + Ajout du fichier .gitignore)
		# donc on les crée comme des branches, ensuite on les modifie, on en crée un tag GIT et on supprime la branche pour ne conserver que le tag
		
		if [[ $svn_stdandard_migration == "1" ]]; then
			echo "=== Migration standard ==="
			echo "=== Récupération du projet distant SVN en dépôt local GIT ==="
			echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --stdlayout "$svn_repo_URL" "$LOCAL_PROJECT"/"$git_repo_name" ==="
			git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --stdlayout $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
		else
			echo "=== Migration personnalisée ==="
			if [[ $svn_customers_rootDir == "NA" ]] && [[ $svn_features_rootDir == "NA" ]] && [[ $svn_releases_rootDir == "NA" ]] && [[ $svn_tags_rootDir == "NA" ]] && [[ $svn_trunk_rootDir == "NA" ]]; then
				# Projet non mavenisé
				echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
				git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
			else
				################################################################
				# Récupération du projet distant SVN (trunk, branches et tags) #
				################################################################
				if [[ $svn_customers_rootDir != "NA" ]]; then
					if [[ $svn_features_rootDir != "NA" ]]; then
						if [[ $svn_releases_rootDir != "NA" ]]; then
							if [[ $svn_tags_rootDir != "NA" ]]; then
								if [[ $svn_trunk_rootDir != "NA" ]]; then
									# svn_customers_rootDir, svn_features_rootDir, svn_releases_rootDir, svn_tags_rootDir et svn_trunk_rootDir renseignés
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir --branches=$svn_features_rootDir --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								else
									# svn_customers_rootDir, svn_features_rootDir, svn_releases_rootDir et svn_tags_rootDir renseignés
									# svn_trunk_rootDir vaut NA
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir --branches=$svn_features_rootDir --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								fi
							else
								if [[ $svn_trunk_rootDir != "NA" ]]; then
									# svn_customers_rootDir, svn_features_rootDir, svn_releases_rootDir et svn_trunk_rootDir renseignés
									# svn_tags_rootDir vaut NA
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir --branches=$svn_features_rootDir --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								else
									# svn_customers_rootDir, svn_features_rootDir et svn_releases_rootDir renseignés
									# svn_tags_rootDir et svn_trunk_rootDir valent NA
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir --branches=$svn_features_rootDir --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								fi
							fi
						else
							if [[ $svn_tags_rootDir != "NA" ]]; then
								if [[ $svn_trunk_rootDir != "NA" ]]; then
									# svn_customers_rootDir, svn_features_rootDir, svn_tags_rootDir et svn_trunk_rootDir renseignés
									# svn_releases_rootDir vaut NA
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir --branches=$svn_features_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								else
									# svn_customers_rootDir, svn_features_rootDir et svn_tags_rootDir renseignés
									# svn_releases_rootDir et svn_trunk_rootDir valent NA
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir --branches=$svn_features_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								fi
							else
								if [[ $svn_trunk_rootDir != "NA" ]]; then
									# svn_customers_rootDir, svn_features_rootDir et svn_trunk_rootDir renseignés
									# svn_releases_rootDir et svn_tags_rootDir valent NA
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir --branches=$svn_features_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								else
									# svn_customers_rootDir et svn_features_rootDir renseignés
									# svn_releases_rootDir et svn_tags_rootDir et svn_trunk_rootDir valent NA
									echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" --branches="$svn_features_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
									git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir --branches=$svn_features_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
								fi
							fi
						fi
					elif [[ $svn_releases_rootDir != "NA" ]]; then
						if [[ $svn_tags_rootDir != "NA" ]]; then
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_customers_rootDir, svn_releases_rootDir, svn_tags_rootDir et svn_trunk_rootDir renseignés
								# svn_features_rootDir vaut NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_customers_rootDir, svn_releases_rootDir et svn_tags_rootDir renseignés
								# svn_features_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						else
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_customers_rootDir, svn_releases_rootDir et svn_trunk_rootDir renseignés
								# svn_features_rootDir et svn_tags_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_customers_rootDir et svn_releases_rootDir renseignés
								# svn_features_rootDir, svn_tags_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						fi
					else
						if [[ $svn_tags_rootDir != "NA" ]]; then
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_customers_rootDir, svn_tags_rootDir et svn_trunk_rootDir renseigné
								# svn_features_rootDir et svn_releases_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_customers_rootDir et svn_tags_rootDir renseigné
								# svn_features_rootDir et svn_releases_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						else
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_customers_rootDir et svn_trunk_rootDir renseigné
								# svn_features_rootDir, svn_releases_rootDir et svn_tags_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_customers_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_customers_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_customers_rootDir renseigné
								# svn_features_rootDir, svn_releases_rootDir, svn_tags_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_customers_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_customers_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						fi
					fi
				elif [[ $svn_features_rootDir != "NA" ]]; then
					if [[ $svn_releases_rootDir != "NA" ]]; then
						if [[ $svn_tags_rootDir != "NA" ]]; then
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_features_rootDir et svn_releases_rootDir, svn_tags_rootDir et svn_trunk_rootDir renseignés
								# svn_customers_rootDir vaut NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_features_rootDir --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_features_rootDir, svn_releases_rootDir et svn_tags_rootDir renseignés
								# svn_customers_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_features_rootDir --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						else
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_features_rootDir, svn_releases_rootDir et svn_trunk_rootDir renseignés
								# svn_customers_rootDir et svn_tags_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_features_rootDir --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_features_rootDir et svn_releases_rootDir renseignés
								# svn_customers_rootDir, svn_tags_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_features_rootDir" --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_features_rootDir --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						fi
					else
						if [[ $svn_tags_rootDir != "NA" ]]; then
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_features_rootDir, svn_tags_rootDir et svn_trunk_rootDir renseignés
								# svn_customers_rootDir et svn_releases_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_features_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_features_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_features_rootDir et svn_tags_rootDir renseignés
								# svn_customers_rootDir, svn_releases_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_features_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_features_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						else
							if [[ $svn_trunk_rootDir != "NA" ]]; then
								# svn_features_rootDir et svn_trunk_rootDir renseignés
								# svn_customers_rootDir, svn_releases_rootDir et svn_tags_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_features_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_features_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							else
								# svn_features_rootDir renseigné
								# svn_customers_rootDir, svn_releases_rootDir, svn_tags_rootDir et svn_trunk_rootDir valent NA
								echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_features_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
								git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_features_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
							fi
						fi
					fi
				elif [[ $svn_releases_rootDir != "NA" ]]; then
					if [[ $svn_tags_rootDir != "NA" ]]; then
						if [[ $svn_trunk_rootDir != "NA" ]]; then
							# svn_releases_rootDir, svn_tags_rootDir et svn_trunk_rootDir renseignés
							# svn_customers_rootDir et svn_features_rootDir valent NA
							echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
							git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
						else
							# svn_releases_rootDir et svn_tags_rootDir renseignés
							# svn_customers_rootDir, svn_features_rootDir et svn_trunk_rootDir valent NA
							echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_releases_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
							git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_releases_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
						fi
					else
						if [[ $svn_trunk_rootDir != "NA" ]]; then
							# svn_releases_rootDir et svn_trunk_rootDir renseignés
							# svn_customers_rootDir, svn_features_rootDir et svn_tags_rootDir valent NA
							echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
							git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
						else
							# svn_releases_rootDir renseigné
							# svn_customers_rootDir, svn_features_rootDir, svn_tags_rootDir et svn_trunk_rootDir valent NA
							echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_releases_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
							git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_releases_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
						fi
					fi
				else
					if [[ $svn_tags_rootDir != "NA" ]]; then
						if [[ $svn_trunk_rootDir != "NA" ]]; then
							# svn_tags_rootDir et svn_trunk_rootDir renseignés
							# svn_customers_rootDir, svn_features_rootDir et svn_releases_rootDir valent NA
							echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
							git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
						else
							# svn_tags_rootDir renseigné
							# svn_customers_rootDir, svn_features_rootDir et svn_releases_rootDir valent NA
							echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --branches="$svn_tags_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
							git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --branches=$svn_tags_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
						fi
					else
						if [[ $svn_trunk_rootDir != "NA" ]]; then
							# svn_trunk_rootDir renseigné
							# svn_customers_rootDir, svn_features_rootDir, svn_releases_rootDir et svn_tags_rootDir valent NA
							echo "=== Commande passée : git svn clone --prefix="" --authors-file="$HOME"/file/authors_"$svn_repo_name".txt --trunk="$svn_trunk_rootDir" "$svn_repo_URL $LOCAL_PROJECT"/"$git_repo_name
							git svn clone --prefix="" --authors-file=$HOME/file/authors_$svn_repo_name.txt --trunk=$svn_trunk_rootDir $svn_repo_URL $LOCAL_PROJECT/$git_repo_name
						else
							echo "=== Les champs 'svn_customers_rootDir', 'svn_features_rootDir', 'svn_releases_rootDir', 'svn_tags_rootDir' et 'svn_trunk_rootDir' valent tous 'NA' ==="
							echo "=== Le projet '"$svn_repo_URL"' ne peut pas être migré ==="
						fi
					fi
				fi
				####################################################################
				# Fin récupération du projet distant SVN (trunk, branches et tags) #
				####################################################################
			fi
		fi
		cd $LOCAL_PROJECT/$git_repo_name
		###############################
		# Convertion des branches SVN #
		###############################
		echo "=== Conversion des branches ==="
		# Nom du fichier listant les tags à migrer par projet svn
		SVN_TAGS_TO_MIGRATE_FILE=$HOME_PROJECT/file/$git_repo_name/config_tags_to_migrate.csv
		if [[ ! -e $SVN_TAGS_TO_MIGRATE_FILE ]]; then
			echo "=== Info - File '"$SVN_TAGS_TO_MIGRATE_FILE"' not found"
		fi
		# Nom du fichier listant les branches customer à migrer par projet svn
		SVN_CUSTOMER_BRANCHES_TO_MIGRATE_FILE=$HOME_PROJECT/file/$git_repo_name/config_branches_customer_to_migrate.csv
		if [[ ! -e $SVN_CUSTOMER_BRANCHES_TO_MIGRATE_FILE ]]; then
			echo "=== Info - File '"$SVN_CUSTOMER_BRANCHES_TO_MIGRATE_FILE"' not found"
		fi
		# Nom du fichier listant les branches feature à migrer par projet svn
		SVN_FEATURE_BRANCHES_TO_MIGRATE_FILE=$HOME_PROJECT/file/$git_repo_name/config_branches_feature_to_migrate.csv
		if [[ ! -e $SVN_FEATURE_BRANCHES_TO_MIGRATE_FILE ]]; then
			echo "=== Info - File '"$SVN_FEATURE_BRANCHES_TO_MIGRATE_FILE"' not found"
		fi
		# Nom du fichier listant les branches feature à migrer par projet svn
		SVN_RELEASE_BRANCHES_TO_MIGRATE_FILE=$HOME_PROJECT/file/$git_repo_name/config_branches_release_to_migrate.csv
		if [[ ! -e $SVN_RELEASE_BRANCHES_TO_MIGRATE_FILE ]]; then
			echo "=== Info - File '"$SVN_RELEASE_BRANCHES_TO_MIGRATE_FILE"' not found"
		fi
		git for-each-ref --format='%(refname:short)' refs/remotes |
		while read b
		do
			found="0"
			tag="0"
			customer="0"
			feature="0"
			release="0"
			# Si le nom de la branche commence par '-' ou bien contient '*' on ne la traite pas
			string=${b:0:1}
			pos=`expr index $b '*'`
			if [[ $string != "-" ]] || [[ $pos == 0 ]]; then
				if [[ -e $SVN_TAGS_TO_MIGRATE_FILE ]]; then
					# Convertion des branches SVN 'tag'
					echo "=== grep -w "$b" "$SVN_TAGS_TO_MIGRATE_FILE" ==="
					grep=`grep -w $b $SVN_TAGS_TO_MIGRATE_FILE`
					grep=`tr -d "\r" <<< "$grep"`
					if [[ $b == $grep ]]; then
						found="1"
						tag="1"
						echo "=== Convertion du tag SVN customer local '"$b"' en branche GIT locale temporaire ==="
						git branch tags/$b refs/remotes/$b
					fi
				fi
				if [[ $found == "0" ]]; then
					if [[ -e $SVN_CUSTOMER_BRANCHES_TO_MIGRATE_FILE ]]; then
						# Convertion des branches SVN 'customer'
						echo "=== grep -w "$b" "$SVN_CUSTOMER_BRANCHES_TO_MIGRATE_FILE" ==="
						grep=`grep -w $b $SVN_CUSTOMER_BRANCHES_TO_MIGRATE_FILE`
						grep=`tr -d "\r" <<< "$grep"`
						if [[ $b == $grep ]]; then
							found="1"
							customer="1"
							echo "=== Convertion de la branche SVN customer locale '"$b"' en branche GIT locale ==="
							git branch hotfix/$b refs/remotes/$b
						fi
					fi
					if [[ $found == "0" ]]; then
						if [[ -e $SVN_FEATURE_BRANCHES_TO_MIGRATE_FILE ]]; then
							# Convertion des branches SVN 'feature'
							echo "=== grep -w "$b" "$SVN_FEATURE_BRANCHES_TO_MIGRATE_FILE" ==="
							grep=`grep -w $b $SVN_FEATURE_BRANCHES_TO_MIGRATE_FILE`
							grep=`tr -d "\r" <<< "$grep"`
							if [[ $b == $grep ]]; then
								found="1"
								feature="1"
								echo "=== Convertion de la branche SVN feature locale '"$b"' en branche GIT locale ==="
								git branch feature/$b refs/remotes/$b
							fi
						fi
					fi
					if [[ $found == "0" ]]; then
						if [[ -e $SVN_RELEASE_BRANCHES_TO_MIGRATE_FILE ]]; then
							# Convertion des branches SVN 'realease'
							echo "=== grep -w "$b" "$SVN_RELEASE_BRANCHES_TO_MIGRATE_FILE" ==="
							grep=`grep -w $b $SVN_RELEASE_BRANCHES_TO_MIGRATE_FILE`
							grep=`tr -d "\r" <<< "$grep"`
							if [[ $b == $grep ]]; then
								found="1"
								release="1"
								echo "=== Convertion de la branche SVN release locale '"$b"' en branche GIT locale ==="
								git branch release/$b refs/remotes/$b
							fi
						fi
					fi
				fi
				# Adaptation post-migration des branches SVN créées
				if [[ $tag == "1" ]]; then
					( adaptBranchToGIT tags/$b $connector ) && ( git tag $b )
					echo "=== Création du tag GIT local '"$b"' ==="
					echo "=== Suppression de la branche GIT locale temporaire '"$b"' ==="
					git checkout master && git branch -D tags/$b
				elif [[ $customer == "1" ]]; then
					adaptBranchToGIT hotfix/$b $connector
				elif [[ $feature == "1" ]]; then
					adaptBranchToGIT feature/$b $connector
				elif [[ $release == "1" ]]; then
					adaptBranchToGIT release/$b $connector
				fi
			fi
		done
		# Adaptation post-migration du master
		if [[ $svn_trunk_rootDir != "NA" ]]; then
			adaptBranchToGIT "master" $connector
		#else
		#	git branch -D master
		fi
		######################################
		# Fin de convertion des branches SVN #
		######################################
		##################################
		# Nettoyage des branches locales #
		##################################
		echo "=== Suppression des potentielles branches parasite qui ne sont pas dans le répertoire 'origin' ==="
		cd $LOCAL_PROJECT/$git_repo_name/.git/refs/remotes
		rm -f -- *
		#########################################
		# Fin de nettoyage des branches locales #
		#########################################
		###################################
		# Remontée dans le repo bitbucket #
		###################################
		echo "=== Remontée du repo '$repo' dans Bitbucket ==="
		git remote add origin $repo
		git remote set-url origin $repo
		git push -u origin --all
		git push origin --tags
		##########################################
		# Fin de remontée dans le repo bitbucket #
		##########################################
	fi
done < $SVN_PROJECTS_CONF_FILE

cd $LOCAL_PROJECT
chmod -R 775 *
cd $HOME_PROJECT/bin
echo "=== "`date +"%Y-%m-%d %T"`" ==="
echo "================================"
echo "=== Reprise SVN GIT terminée ==="
echo "================================"