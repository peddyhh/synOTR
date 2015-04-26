#!/bin/sh
	#	Changelog:
	#	0.6	
	#	 - 	Fehler bei Modellen mit evensport-CPU behoben
	#	0.5:
	#	 -  Benachrichtigung für fertige Aufgaben in DSM-Benachrichtigung
	#	 - 	Benachrichtigung für fertige Aufgaben per kurzen Piep
	#	 - 	Das Dateidatum wird auf das Ausstrahlungsdatum gesetzt, sofern Rename aktiv ist (bessere Sortiermöglichkeiten)
	#	 - 	Serieninformationen werden von www.otr-serien.de importiert und die Dateien entsprechend umbenannt
	#	0.4:
	#	 - 	Rename: Korrektur bei Sendernamen
	#	 - 	Cutlisten werden jetzt nach Dateigröße und wenn nicht vorhanden, dann zusätzlich auch nach Dateinamen gesucht
	#	 - 	Updateabfrage (DSM-Benachrichtigung funktioniert nur, wenn das Script als Benutzer "root" aufgerufen wird)


#######################################################################	
VERSION="0.6" # [2015-01-06]

# Arbeitsverzeichnis auslesen und hineinwechseln:
workdir=$(cd $(dirname $0);pwd)
cd $workdir
echo "Arbeitsverzeichnist ist: $workdir"

# PATH anpassen:
#PATH=/opt/bin:/opt/sbin:$PATH
PATH=$workdir/app/bin:$PATH
#export PATH

# Konfigurationsdatei einbinden:
CONFIG=Konfiguration.txt
. ./$CONFIG

# Pfad zu DSM-ffmpeg (oder anderer gewünschter Version):
ffmpeg="/usr/syno/bin/ffmpeg"
#ffmpeg="/volume1/homes/admin/script/bin/ffmpeg_fdk/ffmpeg"
timediff="1"									# Abweichung der Dateiänderungszeit in Minuten um laufende FTP-Pushaufträge nicht zu decodieren

OTRkeydeldir="${OTRkeydeldir%/}/"
if [ -d "$OTRkeydeldir" ]; then
		echo "Löschverzeichnis vorhanden"
	else
		mkdir "$OTRkeydeldir"		
fi
echo "Löschverzeichnis ist: $OTRkeydeldir"

destdir="${destdir%/}/"
decodir="${destdir%/}/_decodiert"
if [ -d "$decodir" ]; then
		echo "Decodierverzeichnis vorhanden"
	else
		mkdir "${destdir%/}/_decodiert"		
fi

if [ $OTRcutactiv = "off" ] ; then
	decodir="$destdir"
fi
echo "Decodierverzeichnis ist: $decodir"

#lastjob für Benachrichtigung:
if [ $OTRrenameactiv = "on" ] ; then
		lastjob=4
	elif [ $OTRavi2mp4active = "on" ] ; then
		lastjob=3
	elif [ $OTRcutactiv = "on" ] ; then
		lastjob=2
	else
		lastjob=1
fi

#Diese Funktion sucht nach einer neuen Version von synOTR
update ()
{
	online_version=$(wget -q -O - http://geimist.eu/synOTR/VERSION | /usr/bin/tr -d "\r")
	echo "online_version= $online_version"
	if [ 1 -eq "$(echo "${VERSION} < ${online_version}" | bc)" ]; then  
		echo -e "Es ist eine neue Version verfügbar."
		echo -e "Verwendete Version: $VERSION"
		echo -e "Aktuelle Version: $online_version"
		echo "Die neue Version kann unter \"http://geimist.eu/synOTR/\" heruntergeladen werden."
		message="Es ist eine neue Version von synOTR verfügbar. <br>Verwendete Version: $VERSION <br>Aktuelle Version: $online_version <br><br>Die neue Version kann unter \"<a href=\"http://geimist.eu/synOTR/\">http://geimist.eu/synOTR</a>\" heruntergeladen werden. <a href=\"https://geimist.eu/synOTR/changelog/\">(ChangeLOG)</a><br>"
		synodsmnotify @administrators "synOTR" "$message"
	else
		echo -e "Update ==> Es wurde keine neuere Version gefunden. Du nutzt synOTR-Version: $VERSION"
	fi
}


OTRdecoder ()
	{
	if [ $decoderactiv = "on" ] ; then
			echo "==> decodieren:"
			OTRkeydir="${OTRkeydir%/}/"
			for i in $(find "$OTRkeydir" -maxdepth 1 -name "*.otrkey" -mmin +"$timediff" -type f)
				do	
					filename=`basename "$i"`
					echo $filename
					otrdecoderLOG=$(otrdecoder -q -i "$i" -o "$decodir" -e "$OTRuser" -p "$OTRpw" 2>&1)
					echo "OTRdecoder LOG: $otrdecoderLOG"
			         #	!!!! Rückgabewert "[OTRHelper:] Error: No connection to server!" löscht Dateien, ohne zu dekodieren						
					if [ $(echo $otrdecoderLOG | grep "[OTRHelper:] Error: No connection to server!") ] ; then
							echo "OTRDecoder konnte keine Verbindung zum OTR-Server aufbauen. Datei wird übersprungen."
							continue ; 
						else 
		 		        	mv "$i" "$OTRkeydeldir"	
							if [ $lastjob -eq 1 ] ; then
								if [ $dsmtextnotify = "on" ] ; then
									synodsmnotify @administrators "synOTR" "$filename ist fertig"
								fi
								if [ $dsmbeepnotify = "on" ] ; then
									    echo 2 > /dev/ttyS1 #short beep
								fi
							fi	
					fi
				done
		elif [ $decoderactiv = "off" ] ; then
			echo "==> decodieren ist deaktiviert"
		else
			echo "==> Variable für Decodieraktivität falsch gesetzt ==> Wert >decoderactiv< in Konfiguration.txt überprüfen!"
	fi
	}
	
	
OTRcut ()
	{
	if [ $OTRcutactiv = "on" ] ; then
			echo -e ; echo -e; echo "==> schneiden:"		
			for i in $(find "$decodir" -maxdepth 1 -name "*.avi" -o -name "*.mp4" -type f)
				do
					filename=`basename "$i"`
					echo -e ; echo -e 
					echo "SCHNEIDE: ==> $filename" ; echo -e
					if echo "$filename" | grep -q ".mp4"; then		
						echo "$filename [.mp4-Datei] kann mit avisplit / avimerge nicht geschnitten werden"
						mv $i "$destdir"
						continue		# nächste Datei
					fi
         			bash $workdir/app/OTRcut.sh --force-smart -a -e --delete --toprated -i "$i" -o "$destdir" --deldir "$OTRkeydeldir" --wd $workdir/$CONFIG #--lj $lastjob
				done
		elif [ $OTRcutactiv = "off" ] ; then
			echo "==> schneiden ist deaktiviert"
		else
			echo "==> Variable für Cutaktivität falsch gesetzt ==> Wert >OTRcutactiv< in Konfiguration.txt überprüfen!"
	fi
	}
	
	
OTRavi2mp4 ()
	{
	cd $destdir
	if [ $OTRavi2mp4active = "on" ] ; then
			echo -e ; echo -e; echo "==> in MP4 konvertieren:"	
			IFS="
			"
			for i in $(find "$destdir" -maxdepth 1 -name "*.avi" -type f)
				do
					title=`basename $i`
					pfad=`dirname $i`
					pfad="$pfad/"
					title=${title%.*}

					#	-------AUDIOCODEC:																
					fileinfo=$(ffmpeg -i "$i" 2>&1)		
					audiotypepos=`echo $fileinfo | awk '{ print index($0, "Audio: ") }'` 			
					let audiotypepos=$audiotypepos+7												
					let audiotypeposend=$audiotypepos+2												
					audiocodec=`echo $fileinfo | cut -c $audiotypepos-$audiotypeposend `					
					audiofile="$destdir$title.$audiocodec"
					echo Audiocodec: $audiocodec

					if [ $audiocodec = "aac" ] ; then
						echo "Datei scheint bereits ein mp4 zu sein ==> springe zu nächster Datei:"
						continue
					fi
		
					#	-------VIDEOCODEC:															
					if [ $(echo $fileinfo | grep "mpeg4") ] ; then
							videocodec="divx"
							vExt="tmp.m4v"; 
						elif [ $(echo $fileinfo | grep "h264") ] ; then
							videocodec="h264"
							vExt="h264"
						else 
							videocodec="unknown"
							echo "Videoformat nicht erkannt. ==> springe zu nächster Datei:"
							continue ; 
					fi
					echo "Videocodec: $videocodec"
					videofile="$destdir$title.$vExt"
			
					#	-------FRAMERATE:																
					if [ $(echo $fileinfo | grep "50 fps") ] ; then
							fps="50"; 
						elif [ $(echo $fileinfo | grep "25 fps") ] ; then
							fps="25"
						else 
							fps="25"
					fi
					echo "Framerate ist: $fps"

#	-------DEMUX:		
					#	-------Audio extrahieren / konvertieren:
					$ffmpeg -i "$i" -acodec copy -vn $audiofile
					if [ $audiocodec != "aac" ] ; then
						$ffmpeg -threads 2 -i "$audiofile" -acodec libfaac -ab "${OTRaacqal%k}k" "$audiofile.m4a" 	#libfaac > für syno-ffmpeg
#						$ffmpeg -threads 2 -i "$audiofile" -c:a libfdk_aac -b:a "${OTRaacqal%k}k" "$audiofile.m4a"				# für libfdk_aac

						rm $audiofile	
						audiofile="$audiofile.m4a"
					fi
	
					#	-------Video extrahieren:
					$ffmpeg -i "$i" -an -vcodec copy $videofile

#	-------REMUX:
					echo audiofile ist: $audiofile
					echo videofile ist: $videofile
					mp4box -add "$videofile" -add "$audiofile" -flat -fps $fps "$pfad$title.mp4"

					#	-------Temp löschen:
					rm $videofile
					rm $audiofile

					#	-------Original löschen:
					mv "$i" "$OTRkeydeldir"
					
					if [ $lastjob -eq 3 ] ; then
							if [ $dsmtextnotify = "on" ] ; then
								synodsmnotify @administrators "synOTR" "$title ist fertig"
							fi
							if [ $dsmbeepnotify = "on" ] ; then
							    echo 2 > /dev/ttyS1 #short beep
							fi
					fi
			done	
		elif [ $OTRavi2mp4active = "off" ] ; then
			echo "==> in MP4 konvertieren ist deaktiviert"
		else
			echo "==> Variable für OTRavi2mp4active falsch gesetzt ==> Wert >OTRavi2mp4active< in Konfiguration.txt überprüfen!"
	fi
	}
	

OTRrename ()
	{
			echo -e ; echo -e; echo "==> OTRrename:"
			for i in $(find "$destdir" -maxdepth 1 -name "*TVOON*avi" -o -name "*TVOON*mp4" -type f)
				do
					sourcename=`basename "$i"`
					filename=`basename "$i"`
					echo -e ; echo "	==> $filename:" ; echo -e 
					fileextension="${filename##*.}"
					echo "fileextension ist: $fileextension"
					# unerwünschte Zeichen korrigieren (u.a. durch OTRcut):
					# Der_Tatortreiniger_14.11.21_22-40_orf3_30_TVOON_DE.HQ-cut.avi
					# Der_Tatortreiniger_14.12.03_22-00_ndr_30_TVOON_DE.mpg.HD.avi-cut.avi
					filename=`echo $filename | sed 's/HQ-cut/mpg.HQ/g'`	
					filename=`echo $filename | sed 's/HD-cut/mpg.HD/g'`	
	#				filename=`echo $filename | sed 's/.avi-cut//g'`	
					filename=`echo $filename | sed 's/mpg.HD.avi-cut.avi/mpg.HD.avi/g'`	
	#				filename=`echo $filename | sed 's/mpg.HD.avi-cut./mpg.HD./g'`	
					filename=`echo $filename | sed 's/DE-cut/DE.mpg/g'`	
					#filename=`echo $filename | sed 's///g'`	# mp4 fehlt noch

#Beispiel für mp4 LQ:	Tagesschau_14.12.22_20-00_ndr_15_TVOON_DE.mpg.mp4

					#	------------------ FORMAT:
					if echo "$filename" | grep -q ".HQ."; then							
							film_ohne_ende=${filename%%_TVOON_DE.mpg.HQ.*}
							format=HQ
						elif echo "$filename" | grep -q ".HD"; then					
							film_ohne_ende=${filename%%_TVOON_DE.mpg.HD.*}
							format=HD
						elif echo "$filename" | grep -q ".mpg.mp4"; then		
							film_ohne_ende=${filename%%_TVOON_DE.mpg.mp4}		
							format=LQ
						else
							film_ohne_ende=${filename%%_TVOON_DE.mpg.*}
							format=SD
					fi
					echo "Format ist: $format"

					#	------------------ Referenzpunkt suchen:
					ersterpunkt=`echo $filename | awk '{print index($filename, ".")}'`

					#	------------------ Titel:
					titleend=$(($ersterpunkt-4))
					title=`echo $filename | cut -c -$titleend `			
					title=`echo $title | sed 's/__/ - /g'`			
					title=`echo $title | sed 's/_/ /g'`			
					echo "Titel ist: $title"							

					#	------------------ Jahr:
					YYbeginn=$(($ersterpunkt-2))
					YYend=$(($ersterpunkt-1))
					YY=`echo $filename | cut -c $YYbeginn-$YYend `
					echo "YY ist $YY"
					YYYY="20$YY"
					echo "YYYY ist $YYYY"

					#	------------------ Monat:
					Mobeginn=$(($ersterpunkt+1))
					Moend=$(($ersterpunkt+2))
					Mo=`echo $filename | cut -c $Mobeginn-$Moend `
					echo "Monat ist $Mo"

					#	------------------ Tag:
					DDbeginn=$(($ersterpunkt+4))
					DDend=$(($ersterpunkt+5))
					DD=`echo $filename | cut -c $DDbeginn-$DDend `
					echo "Tag ist $DD"

					#	------------------ Stunde:
					HHbeginn=$(($ersterpunkt+7))
					HHend=$(($ersterpunkt+8))
					HH=`echo $filename | cut -c $HHbeginn-$HHend `
					echo "Stunde ist $HH"					
					
					#	------------------ Minute:
					Minbeginn=$(($ersterpunkt+10))
					Minend=$(($ersterpunkt+11))
					Min=`echo $filename | cut -c $Minbeginn-$Minend `
					echo "Minute ist $Min"

					#	------------------ Dauer:
					duration=`echo $film_ohne_ende | sed 's/.*_ *//;T;s/ *_.*//'`
					echo "Dauer ist $duration"
					
					#	------------------ Sender:
					Channel=$(echo "$filename" | rev | awk -F '_' '{print $4}' | rev)
					echo "Sender ist $Channel"
					
					NewName=$NameSyntax		# Muster aus Konfiguration laden

					# Serieninformationen holen - VIELEN DANK AN Daniel Dieth VON www.otr-serien.de :
					if [ $OTRserieninfo = "on" ] ; then
						serieninfo=$(curl "http://www.otr-serien.de/myapi/reverseotrkeycheck.php?otrkey=$i&who=synOTR" )
						# Erfolglosmeldung Serieninfo: <!DOCTYPE html> Keine Serien zuordnung vorhanden	
						if echo "$serieninfo" | grep -q "Keine Serien zuordnung vorhanden"; then
							echo "Keine Serieninformation für "$title" vorhanden"
							echo "Es wird 48h lang nach Serieninformationen gesucht. "
							echo -e "Nach diesem Zeitraum wird die herkömmliche Umbenennung angewandt."
							
							# Vorgebende Zeit nach Serieninformationen suchen - wenn negativ, dann normale Umbenennung
							filesuche=$(find "$destdir" -maxdepth 1 -name "$sourcename" -mmin +2880)
						
							if [ -f "$filesuche" ]; then
									echo "Zeit für Seriensuche überschritten ==> verwende einfache Umbenennung."
									NewName=`echo $NewName | sed "s/§tit/${title}/g"`
								else
									echo "==> weiter auf Serieninformationen warten"
									continue
							fi
						else
							serieninfo=`echo $serieninfo | sed "s/<!DOCTYPE html>//g" | sed 's/\\\u00e4/ä/g' | sed 's/\\\u00f6/ö/g' | sed 's/\\\u00c4/Ä/g' | sed 's/\\\u00d6/Ö/g' | sed 's/\\\u00fC/ü/g' | sed 's/\\\u00dC/Ü/g' | sed 's/\\\u00dF/ß/g' `
						
							OTRID=`echo "$serieninfo" | awk -F, '{print $1}' | awk -F: '{print $2}' | sed "s/\"//g"`
							echo "OTRID: $OTRID"
							serietitle=`echo "$serieninfo" | jq -r '.Serie'`		# jq ist ein Kommandozeilen-JSON-Parser
							echo "serietitle: $serietitle"	
							season=`echo "$serieninfo" | awk -F, '{print $3}' | awk -F: '{print $2}' | sed "s/\"//g"`
							season="$(printf '%02d' "$season")"		# 2stellig mit führender Null
							echo "season: $season"	
							episode=`echo "$serieninfo" | awk -F, '{print $4}' | awk -F: '{print $2}' | sed "s/\"//g"`
							episode="$(printf '%02d' "$episode")"	# 2stellig mit führender Null
							echo "episode: $episode"	
							episodetitle=`echo "$serieninfo" | jq -r '.Folgenname'`
							echo "episodetitle: $episodetitle"	
							description=`echo "$serieninfo" | jq -r '.Folgenbeschreibung'`
							echo "description: $description"
							
							title="$serietitle - S${season}E${episode} $episodetitle"
							NewName=`echo $NewName | sed "s/§tit/${title}/g"`
						fi
					fi

					#	------------------ Neuer Name:
					#	verwendbare Tags:	$duration $title $YYYY $YY $Mo $DD $HH $Min $Channel $format sowie freier Text und Zeichen					
					NewName=`echo $NewName | sed "s/§dur/${duration}/g"`
					NewName=`echo $NewName | sed "s/§tit/${title}/g"`
					NewName=`echo $NewName | sed "s/§ylong/${YYYY}/g"`
					NewName=`echo $NewName | sed "s/§yshort/${YY}/g"`
					NewName=`echo $NewName | sed "s/§mon/${Mo}/g"`
					NewName=`echo $NewName | sed "s/§day/${DD}/g"`
					NewName=`echo $NewName | sed "s/§hou/${HH}/g"`
					NewName=`echo $NewName | sed "s/§min/${Min}/g"`
					NewName=`echo $NewName | sed "s/§cha/${Channel}/g"`
					NewName=`echo $NewName | sed "s/§qua/${format}/g"`

					NewName="$NewName.$fileextension"					
					echo "Neuer Dateiname ist $NewName"
					
					
					if [ $OTRrenameactiv = "on" ] ; then
							echo "==> umbenennen:"	
							touch -t $YY$Mo$DD$HH$Min $i 			# Dateidatum auf Ausstrahlungsdatum setzen:
							if [ -f "$destdir$NewName" ]; then		# Prüfen, ob Zielname bereits vorhanden ist
								echo "Die Datei $NewName ist bereits vorhanden und $filename wird nicht umbenannt."
							else	
								mv -i $i "$destdir$NewName"

								#	Tags schreiben (MP4 only):
								#  --TVNetwork    (string)     Set the TV Network name
								#  --TVShowName   (string)     Set the TV Show name
								#  --TVEpisode    (string)     Set the TV episode/production code
								#  --TVSeasonNum  (number)     Set the TV Season number
								#  --TVEpisodeNum (number)     Set the TV Episode number
								#  --description 
								#  --artwork
								#  --genre 
								#	deaktiviert / tmp-Datei wird nicht gegen Original ausgetauscht …
#								AtomicParsley "$destdir$NewName" --TVNetwork $Channel --TVShowName $serietitle --TVEpisode $episodetitle --TVSeasonNum $season --TVEpisodeNum $episode --title $title
								
								echo "umbenannt von $filename zu $NewName"
									
								if [ $lastjob -eq 4 ] ; then
									if [ $dsmtextnotify = "on" ] ; then
										synodsmnotify @administrators "synOTR" "$title ist fertig"
									fi
									if [ $dsmbeepnotify = "on" ] ; then
										    echo 2 > /dev/ttyS1 #short beep
									fi
								fi
							fi
						elif [ $OTRrenameactiv = "off" ] ; then
							echo "==> umbenennen ist deaktiviert"
						else
							echo "==> Variable für Renameaktivität falsch gesetzt ==> Wert >OTRrenameactiv< in Konfiguration.txt überprüfen!"
					fi
				done
	}


#	-------Funktionen aufrufen:
	update
	OTRdecoder
	OTRcut
	OTRavi2mp4
	OTRrename
	
exit
