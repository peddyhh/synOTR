#!/bin/sh
##############################################################################
#
# File  :   <linux>:synOTR/synOTR.conf.sample
# Author:   Original:	synotr@geimist.eu (Stephan Geisler)
#			ergaenzt:	peddy@gmx.net (Andreas Peters)
# Date  :   26.04.2015
# Subj. :   Dekodieren und Schneiden von OTR-Dateien auf eine Synology-Maschine
#
#	Changelog:
VERSION="0.62" # [2015-01-06]
#	0.62
#	 -	Whitespaces am Ende einer Zeile entfernt
#	 -	Aufrufparameter eingefuehrt, ohne Parameter wird die Hilfe angezeigt
#	 -	Funktion "update" nach "checkversion" umbenannt
#	 -	STD-Parameter eingefuehrt, mit Ueberschreibemoeglichkeit in der conf-Datei
#	 -  erweitertes Logverfahren eingefuehrt
#	 -	Code etwas umformatiert
#	0.61
#	 -	Kommentare ergaenzt und Kleinigkeiten im Code angepasst
#	 -	Skript umbenannt nach synOTR.sh
#	 -	Konfigurationsdatei umbenannt nach synOTR.conf bzw. synOTR.conf.sample
#	 -  pre-hook Test mit Pattern b_l_u_b_b
#	 -  DRY-Modus eingefuehrt
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
#
#	offene Punkte:
#	- Ausgaben von externen Skripten / Programmen einfangen
#	- Datei- und Verzeichnisrechte aus dem Skript heraus setzen, damit Freigabe via SMB und AFP wie gewohnt geht
#
##############################################################################
Script="${0##*/}" ; Script=${Script%*.sh}; ScriptParameter="$@"
DRY=	 ## wenn leer, dann werden Kommandos ausgefuehrt oder Parameter "-verbose"
#DRY=echo ##	mit "echo" werden keine externen Kommandos ausgefuehrt, sondern angezeigt


# Arbeitsverzeichnis auslesen und hineinwechseln:
workdir=$(cd $(dirname $0);pwd)
cd $workdir # &&  echo "Arbeitsverzeichnist ist: $workdir"

# STD-Logfilename -- wird ggf. in CONFIG-File ueberschrieben
LOGFILE=$workdir/synOTR.log

# STD-Abweichung der Dateiaenderungszeit in Minuten um laufende FTP-Pushauftraege nicht zu decodieren
timediff="2"

# STD-Pfad zu DSM-ffmpeg (oder anderer gewünschter Version):
ffmpeg="/usr/syno/bin/ffmpeg"

# PATH anpassen:
#PATH=/opt/bin:/opt/sbin:$PATH
PATH=$workdir/app/bin:/usr/syno/bin:$PATH
export PATH

#######################################
# Verbose-Level for logging:
# 0: do not print anything to console  1: print only errors to console
# 2: print errors and info to console  3: print errors, info and debug logs to console
VERBOSE=1
DEBUG=false


#######################################
## STD-Werte fuer einige Variablen
## false oder true
CHECKVERSION=false
DECODERACTIVE=false
OTRCUTACTIVE=false
OTRAVI2MP4ACTIVE=false
OTRRENAMEACTIVE=false
OTRSERIENINFO=false
OTRuser=
OTRpw=
OTRKEYdeldir=./
destdir=./
dsmtextnotify="on"
dsmbeepnotify="off"
RC=0	## globaler Return-Code


#######################################
## Konfigurationsdatei
## - kann STD-Parameter ueberschreiben
#######################################
CONFIG=synOTR.conf
. ./$CONFIG

## Korrektur der Verzeichnisberzeichnungen
OTRKEYdeldir=${OTRKEYdeldir%/}/
destdir=${destdir%/}/
decodedir=${destdir%/}/_decodiert/

##############################################################################
## allgemeine Funktionen
##############################################################################
showhelp () {
cat <<EOT

	Meldung: $1
	Usage $Script:
			$Script.sh std | decode | schneide | alles | hilfe | checkversion [-config <configfile>|-dry|-verbose]


EOT
	exit 1
} ## END showhelp ##



#################################################
# Zum sauberen Beenden des Skripts aufrufen
# Einziges Argument ist der ExitCode.
# 0: Alles OK
# >0: Fehler
alreadyExiting=
clean_exit () {
  test $alreadyExiting && return
  alreadyExiting=yes
  local exitcode=${1:-1}
  #trap - ERR INT TERM EXIT
  test $exitcode -gt 0 && log error Exiting with code $exitcode.
  test -w "$LOGFILE" && echo Logfile liegt unter "'${LOGFILE}'"
  exit $exitcode
} ## END clean_exit ##


#################################################
log () {
    local level=$1
    case "$level" in
      error)
          shift;
          test ${VERBOSE} -ge 1 && echo "EMERG: $Script:" "$@" 1>&2		## normal ERROR = CUPS:EMERG:
          test -w "$LOGFILE" && echo $(date '+%F %T') ERROR: "$@" >> "$LOGFILE"
          ;;
      info)
          shift;
          test ${VERBOSE} -ge 2 && echo "$@"
          echo $(date '+%F %T') "INFO: " "$@" >> "${LOGFILE}"
          ;;
      debug)
          shift;
          test ${VERBOSE} -ge 3 && echo "$@"
          echo $(date '+%F %T') DEBUG: "$@" >> "${LOGFILE}"
          ;;
      console)
          shift;
          echo "$@"
          echo $(date '+%F %T') console: "$@" >> "${LOGFILE}"
          ;;
      *)
          log info "$@"
    esac
} ## END log ##

##############
# Benutzen mit
# command 2>&1 | pipeLog
pipeLog () {
	if [ $# -eq 1 ]; then level=$1 ; else level=debug ; fi
	while read data
	do
		log $level "$data"
	done
} ## END pipeLog ##

#################################################
## mehrere Log- und Fehlerbehandlungsfunktionen
fehler () { log error "$@"; clean_exit 1 ; }


#################################################
## Diese Funktion sucht nach einer neuen Version von synOTR
checkversion () {
	online_version=$(wget -q -O - http://geimist.eu/synOTR/VERSION | /usr/bin/tr -d "\r")
	if [ 1 -eq "$(echo "${VERSION} < ${online_version}" | bc)" ]; then
		echo "Es ist eine neue Version verfügbar."
		echo "Verwendete Version: $VERSION"
		echo "Aktuelle Version: $online_version"
		echo "Die neue Version kann unter 'http://geimist.eu/synOTR/' heruntergeladen werden."
		message="Es ist eine neue Version von synOTR verfügbar. <br>Verwendete Version: $VERSION <br>Aktuelle Version: $online_version <br><br>Die neue Version kann unter \"<a href=\"http://geimist.eu/synOTR/\">http://geimist.eu/synOTR</a>\" heruntergeladen werden. <a href=\"https://geimist.eu/synOTR/changelog/\">(ChangeLOG)</a><br>"
		/usr/syno/bin/synodsmnotify @administrators "synOTR" "$message"
	else
		echo "checkversion: es wurde keine neuere Version gefunden. Du nutzt synOTR-Version: $VERSION -- Online-Version: $online_version"
	fi
} ## END checkversion ##


#################################################
OTRdecoder () {
	log info "==> OTRdecoder:"
	OTRKEYdir="${OTRKEYdir%/}/"
	for Datei in $(find "$OTRKEYdir" -maxdepth 1 -name "*.otrkey" -mmin +"$timediff" -type f)
	do
		filename=`basename "$Datei"`
		log info "OTRdecoder: filename: $filename"
		## eigentliche Decodierung
		otrdecoderLOG=$($DRY otrdecoder -q -i "$Datei" -o "$decodedir" -e "$OTRuser" -p "$OTRpw" 2>&1)
		log debug "OTRdecoder: OTRdecoderLOG: $otrdecoderLOG"
         #	!!!! Rückgabewert "[OTRHelper:] Error: No connection to server!" löscht Dateien, ohne zu dekodieren
		if [ $(echo $otrdecoderLOG | grep "[OTRHelper:] Error: No connection to server!") ] ; then
			log error "OTRDecoder: es konnte keine Verbindung zum OTR-Server aufbauen. Datei '$filename' wird uebersprungen."
			continue ;
		else
         	$DRY mv "$Datei" "$OTRKEYdeldir"
			if [ $lastjob -eq 1 ] ; then
				if [ $dsmtextnotify = "on" ] ; then
					/usr/syno/bin/synodsmnotify @administrators "synOTR" "$filename ist fertig"
				fi
				if [ $dsmbeepnotify = "on" ] ; then echo 2 > /dev/ttyS1 ; fi ## short beep
			fi
		fi
	done
} ## END OTRdecoder ##


#################################################
OTRcut () {
	log info "==> OTRcut:"
	for Datei in $(find "$decodedir" -maxdepth 1 -name "*.avi" -o -name "*.mp4" -type f)
	do
		filename=`basename "$Datei"`
		log console "==> OTRcut: schneide '$filename'"
		if echo "$filename" | grep -q ".mp4"; then
			log console "$filename [.mp4-Datei] kann mit avisplit / avimerge nicht geschnitten werden"
			$DRY mv $Datei "$destdir"
			continue		# naechste Datei
		fi
		## das eigentliche Schneiden
   		$DRY bash $workdir/app/OTRcut.sh --force-smart -a -e --delete --toprated -i "$Datei" -o "$destdir" --deldir "$OTRKEYdeldir" --wd $workdir/$CONFIG #--lj $lastjob
	done
} ## END OTRcut ##


#################################################
OTRavi2mp4 () {
	log info "==> OTRavi2mp4:"
	cd $destdir
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
		log find "Audiocodec: $audiocodec"

		if [ $audiocodec = "aac" ] ; then
			log console "Datei scheint bereits ein mp4 zu sein ==> springe zur nächstn Datei:"
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
				log console "Videoformat nicht erkannt. ==> springe zu nächster Datei:"
				continue ;
		fi
		log debug "Videocodec: $videocodec"
		videofile="$destdir$title.$vExt"

		#	-------FRAMERATE:
		if [ $(echo $fileinfo | grep "50 fps") ] ; then
				fps="50";
			elif [ $(echo $fileinfo | grep "25 fps") ] ; then
				fps="25"
			else
				fps="25"
		fi
		log debug "Framerate ist: $fps"

	#	-------DEMUX:
		#	-------Audio extrahieren / konvertieren:
		$DRY $ffmpeg -i "$i" -acodec copy -vn $audiofile
		if [ $audiocodec != "aac" ] ; then
			$DRY $ffmpeg -threads 2 -i "$audiofile" -acodec libfaac -ab "${OTRaacqal%k}k" "$audiofile.m4a" 	#libfaac > für syno-ffmpeg
#			$DRY $ffmpeg -threads 2 -i "$audiofile" -c:a libfdk_aac -b:a "${OTRaacqal%k}k" "$audiofile.m4a"	# für libfdk_aac
			$DRY rm $audiofile
			audiofile="$audiofile.m4a"
		fi

		#	-------Video extrahieren:
		$DRY $ffmpeg -i "$i" -an -vcodec copy $videofile

	#	-------REMUX:
		log debug "audiofile ist: $audiofile"
		log debug "videofile ist: $videofile"
		$DRY mp4box -add "$videofile" -add "$audiofile" -flat -fps $fps "$pfad$title.mp4"

		#	-------Temp loeschen:
		$DRY rm $videofile
		$DRY rm $audiofile

		#	-------Original loeschen:
		$DRY mv "$i" "$OTRKEYdeldir"

		#	-------Fertigstellung melden
		if [ $lastjob -eq 3 ] ; then
			if [ $dsmtextnotify = "on" ] ; then
				/usr/syno/bin/synodsmnotify @administrators "synOTR" "$title ist fertig"
			fi
			if [ $dsmbeepnotify = "on" ] ; then echo 2 > /dev/ttyS1 ; fi #short beep
		fi
	done
} ## END OTRavi2mp4 ##


#################################################
OTRrename () {
	log info "==> OTRrename:"
	for i in $(find "$destdir" -maxdepth 1 -name "*TVOON*avi" -o -name "*TVOON*mp4" -type f)
	do
		sourcename=`basename "$i"`
		filename=`basename "$i"`
		log debug "==> $filename:"
		fileextension="${filename##*.}"
		log debug "fileextension ist: $fileextension"
		# unerwünschte Zeichen korrigieren (u.a. durch OTRcut):
		# Der_Tatortreiniger_14.11.21_22-40_orf3_30_TVOON_DE.HQ-cut.avi
		# Der_Tatortreiniger_14.12.03_22-00_ndr_30_TVOON_DE.mpg.HD.avi-cut.avi
		filename=`echo $filename | sed 's/HQ-cut/mpg.HQ/g'`
		filename=`echo $filename | sed 's/HD-cut/mpg.HD/g'`
	#	filename=`echo $filename | sed 's/.avi-cut//g'`
		filename=`echo $filename | sed 's/mpg.HD.avi-cut.avi/mpg.HD.avi/g'`
	#	filename=`echo $filename | sed 's/mpg.HD.avi-cut./mpg.HD./g'`
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
		log debug "Format ist: $format"

		#	------------------ Referenzpunkt suchen:
		ersterpunkt=`echo $filename | awk '{print index($filename, ".")}'`

		#	------------------ Titel:
		titleend=$(($ersterpunkt-4))
		title=`echo $filename | cut -c -$titleend `
		title=`echo $title | sed 's/__/ - /g'`
		title=`echo $title | sed 's/_/ /g'`
		log debug "Titel ist: $title"

		#	------------------ Jahr:
		YYbeginn=$(($ersterpunkt-2))
		YYend=$(($ersterpunkt-1))
		YY=`echo $filename | cut -c $YYbeginn-$YYend `
		log debug "YY ist $YY"
		YYYY="20$YY"
		log debug "YYYY ist $YYYY"

		#	------------------ Monat:
		Mobeginn=$(($ersterpunkt+1))
		Moend=$(($ersterpunkt+2))
		Mo=`echo $filename | cut -c $Mobeginn-$Moend `
		log debug "Monat ist $Mo"

		#	------------------ Tag:
		DDbeginn=$(($ersterpunkt+4))
		DDend=$(($ersterpunkt+5))
		DD=`echo $filename | cut -c $DDbeginn-$DDend `
		log debug "Tag ist $DD"

		#	------------------ Stunde:
		HHbeginn=$(($ersterpunkt+7))
		HHend=$(($ersterpunkt+8))
		HH=`echo $filename | cut -c $HHbeginn-$HHend `
		log debug "Stunde ist $HH"

		#	------------------ Minute:
		Minbeginn=$(($ersterpunkt+10))
		Minend=$(($ersterpunkt+11))
		Min=`echo $filename | cut -c $Minbeginn-$Minend `
		log debug "Minute ist $Min"

		#	------------------ Dauer:
		duration=`echo $film_ohne_ende | sed 's/.*_ *//;T;s/ *_.*//'`
		log debug "Dauer ist $duration"

		#	------------------ Sender:
		Channel=$(echo "$filename" | rev | awk -F '_' '{print $4}' | rev)
		log debug "Sender ist $Channel"

		NewName=$NameSyntax		# Muster aus Konfiguration laden

		# Serieninformationen holen - VIELEN DANK AN Daniel Dieth VON www.otr-serien.de :
		if $OTRSERIENINFO ; then
			serieninfo=$(curl "http://www.otr-serien.de/myapi/reverseotrkeycheck.php?otrkey=$i&who=synOTR" )
			# Erfolglosmeldung Serieninfo: <!DOCTYPE html> Keine Serien zuordnung vorhanden
			if echo "$serieninfo" | grep -q "Keine Serien zuordnung vorhanden"; then
				log error "Keine Serieninformation für "$title" vorhanden"
				log error "Es wird 48h lang nach Serieninformationen gesucht. "
				log error "Nach diesem Zeitraum wird die herkömmliche Umbenennung angewandt."

				# Vorgebende Zeit nach Serieninformationen suchen - wenn negativ, dann normale Umbenennung
				filesuche=$(find "$destdir" -maxdepth 1 -name "$sourcename" -mmin +2880)

				if [ -f "$filesuche" ]; then
					log info "Zeit für Seriensuche überschritten ==> verwende einfache Umbenennung."
					NewName=`echo $NewName | sed "s/§tit/${title}/g"`
				else
					log info "==> weiter auf Serieninformationen warten"
					continue
				fi
			else
				serieninfo=`echo $serieninfo | sed "s/<!DOCTYPE html>//g" | sed 's/\\\u00e4/ä/g' | sed 's/\\\u00f6/ö/g' | sed 's/\\\u00c4/Ä/g' | sed 's/\\\u00d6/Ö/g' | sed 's/\\\u00fC/ü/g' | sed 's/\\\u00dC/Ü/g' | sed 's/\\\u00dF/ß/g' `

				OTRID=`echo "$serieninfo" | awk -F, '{print $1}' | awk -F: '{print $2}' | sed "s/\"//g"`
				log debug "OTRID: $OTRID"
				serietitle=`echo "$serieninfo" | jq -r '.Serie'`		# jq ist ein Kommandozeilen-JSON-Parser
				log debug "serietitle: $serietitle"
				season=`echo "$serieninfo" | awk -F, '{print $3}' | awk -F: '{print $2}' | sed "s/\"//g"`
				season="$(printf '%02d' "$season")"		# 2stellig mit führender Null
				log debug "season: $season"
				episode=`echo "$serieninfo" | awk -F, '{print $4}' | awk -F: '{print $2}' | sed "s/\"//g"`
				episode="$(printf '%02d' "$episode")"	# 2stellig mit führender Null
				log debug "episode: $episode"
				episodetitle=`echo "$serieninfo" | jq -r '.Folgenname'`
				log debug "episodetitle: $episodetitle"
				description=`echo "$serieninfo" | jq -r '.Folgenbeschreibung'`
				log debug "description: $description"

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
		log debug "Neuer Dateiname ist $NewName"


		if  $OTRRENAMEACTIVE ; then
			log info "==> umbenennen:"
			touch -t $YY$Mo$DD$HH$Min $i 			# Dateidatum auf Ausstrahlungsdatum setzen:
			if [ -f "$destdir$NewName" ]; then		# Prüfen, ob Zielname bereits vorhanden ist
				log info "Die Datei $NewName ist bereits vorhanden und $filename wird nicht umbenannt."
			else
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
				# AtomicParsley "$destdir$NewName" --TVNetwork $Channel --TVShowName $serietitle --TVEpisode $episodetitle --TVSeasonNum $season --TVEpisodeNum $episode --title $title
				$DRY mv -i $i "$destdir$NewName"
				log info "umbenannt von $filename zu $NewName"

				if [ $lastjob -eq 4 ] ; then
					if [ $dsmtextnotify = "on" ] ; then
						/usr/syno/bin/synodsmnotify @administrators "synOTR" "$title ist fertig"
					fi
					if [ $dsmbeepnotify = "on" ] ; then echo 2 > /dev/ttyS1 ;fi #short beep
				fi
			fi
		fi
	done
} ## END OTRrename ##



##############################################################################
## Check Parameter
##############################################################################
log info "=========> Start: $Script"
AnzParam=$#
if [ $AnzParam -lt 1 ]; then showhelp "nicht genug Parameter" ; fi
## Parameterlist siehe "showhelp"
while [ $# -gt 0 ]
do
	case $1 in
		std|-std|--std)
			shift
			[ $VERBOSE -gt 1 ] && log info "verwendet Einstellungen aus conf-Datei"
			;;
		decode|-decode|--decode)
			DECODERACTIVE=true ; shift
			[ $VERBOSE -gt 1 ] && log info "aktiviere das Dekodiren von OTR-Filmdateien"
			;;
		schneide|-schneide|--schneide)
			OTRCUTACTIVE=true ; shift
			[ $VERBOSE -gt 1 ] && log info "aktiviere Schneiden der Filmdateien"
			;;
		alles|-alles|--alles)
			DECODERACTIVE=true
			OTRCUTACTIVE=true
			shift
			[ $VERBOSE -gt 1 ] && log info "aktiviere alle "
			;;
		hilfe|-hilfe|--hilfe|help|-help|--help)
			showhelp "Hilfeanzeige:" ; exit 0
			;;
		checkversion|-checkversion|--checkversion)
			CHECKVERSION=true ; shift
			[ $VERBOSE -gt 1 ] && log info "aktiviere Suche nach neuer Version des Skriptes"
			;;
		dry|-dry|--dry)
			log info "DRY-Modus aktiviert."
			DRY=echo 
			shift
			;;
		verbose|-verbose|--verbose)
			VERBOSE=2
			log info "Verbose-Modus aktiviert."
			shift
			;;
		debug|-debug|--debug)
			VERBOSE=3
			DEBUG=true
			log info "Debug-Modus aktiviert."
			shift
			;;
		*)
			showhelp "Unbekannter Parameter '$1'"
			exit 1;
	esac
done
# lastjob-Variable zur Ermittelung wann Benachrichtigung geschickt werden soll:
                     lastjob=1
    $OTRCUTACTIVE && lastjob=2
$OTRAVI2MP4ACTIVE && lastjob=3
 $OTRRENAMEACTIVE && lastjob=4



##############################################################################
## Check Zutaten
## ??? hier sollte noch mehr Checks rein ???
##############################################################################
if [ ! -d "$OTRKEYdir"		] ; then fehler "Verzeichnis OTRKEYdir '$OTRKEYdir' fehlt, bitte anpassen oder anlegen."		; fi
if [ ! -d "$OTRKEYdeldir"	] ; then fehler	"Verzeichnis OTRKEYdeldir '$OTRKEYdeldir' fehlt, bitte anpassen oder anlegen."	; fi
if [ ! -d "$destdir"		] ; then fehler "Verzeichnis destdir '$destdir' fehlt, bitte anpassen oder anlegen."			; fi
if [ ! -d "$decodedir"		] ; then fehler "Verzeichnis decodedir '${decodedir%/}/' fehlt, bitte anpassen oder anlegen."	; fi
if $OTRCUTACTIVE ; then decodedir="$destdir" ; fi
log debug "OTRKEYdir ist: $OTRKEYdir"
log debug "OTRKEYdeldir ist: $OTRKEYdeldir"
log debug "decodedir ist: $decodedir"
log debug "destdir ist: $destdir"


##############################################################################
##	Hauptprogramm
##############################################################################
$CHECKVERSION		&& checkversion	|| log debug "Check auf neue Skriptversion ausgeschaltet"
$DECODERACTIVE 		&& OTRdecoder	|| log info  "Decodierung der OTRKEY-Dateien ausgeschaltet"
$OTRCUTACTIVE		&& OTRcut		|| log info  "Kein Schneiden der Filmdatei"
$OTRAVI2MP4ACTIVE	&& OTRavi2mp4	|| log info  "Keine Konvertierung von AVI nach MP4"
$OTRRENAMEACTIVE	&& OTRrename	|| log info  "Keine Umbenennung der Zieldateien"

log info "=========> Stop: $Script"
exit $RC
### EOF ###
