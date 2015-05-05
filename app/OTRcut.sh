#!/bin/sh
##############################################################################
#
# File  :   .../synOTR/app/OTRcut.sh
# Author:   peddy@gmx.net (Andreas Peters)
# Date  :   03.05.2015
#
#	Dieses Script schneidet Filme/Serien von http://www.onlinetvrecorder.de
#	anhand der Schnittlisten von http://www.cutlist.at.  Dies geschieht
#	entweder durch avidemux oder avisplit/avimerge.  Avidemux schneidet im
#	Gegensatz zu avisplit/avimerge keyframe-genau.  avisplit/avimerge ist
#	Bestandteil von transcode, avidemux muss separat installiert werden.
#
#	Original-Author: Daniel Siegmanski
#	Homepage: http://www.siggimania4u.de
#	OtrCut Download: http://otrcut.siggimania4u.de
#		Dieses Script darf frei veraendert und weitergegeben werden
#	Zweiter-Author:
#		https://github.com/adlerweb/otrcut.sh/blob/master/otrcut.sh
#
##############################################################################

version=20150503	# Die Version von OtrCut, Format: yyyymmdd, yyyy=Jahr mm=Monat dd=Tag
LocalCutlistOkay=no	# Ist die lokale Cutlist vorhanden?
input=""	# Eingabedatei/en
CutProg=""	# Zu verwendendes Schneideprogramm
LocalCutlistName=""	#Name der lokalen Cutlist
format=""	# Um welches Format handelt es sich? AVI, HQ, mp4
cutlistWithError=""	# Cutlists die, einen Fehler haben
delete=no
continue=0
aspect=169 #	=43 oder =169 Standard-Seitenverhaeltnis

#	Schriftfarben dekativier, um Log in Systemshell besser lesbar zu machen:
rot=""		#"\033[22;31m"	#Rote Schrift
gruen=""	#"\033[22;32m"	#Gruene Schrift
gelb=""		#"\033[22;33m"	#Gelbe Schrift
blau=""		#"\033[22;34m"	#Blaue Schrift
normal=""	#"\033[0m"		#Normale Schrift

# Dieses Variablen werden gesetzt, sofern aber ein Config-File besteht wieder ueberschrieben
UseLocalCutlist=no	# Lokale Cutlists verwenden?
HaltByErrors=no		# Bei Fehlern anhalten?
toprated=no			# Die Cutlist mit der besten User-Bewertung benutzen?
UseAvidemux=yes		# Avidemux verwenden?
ShowAllCutlists=yes # Auswahl mehrerer Cutlists anzeigen?

appdir=$(cd $(dirname $0);pwd -P)	# aktuelles Arbeitsverzeichnis auslesen
tmp="$appdir/tmp" # Zu verwendender Tmp-Ordner, in diesem Ordner wird dann noch ein Ordner "otrcut" erstellt.

overwrite=no	# Bereits vorhandene Dateien ueberschreiben
output=cut		# Ausgabeordner
bewertung=no	# Bewertungsfunktion benutzen
verbose=no		# Ausfuehrliche Ausgabe von avidemux bzw. avisplit/avimerge anzeigen
play=no 		# Datei nach dem Schneiden wiedergeben
warn=no			# Warnung bezueglich der Loeschung von $tmp ausgeben
user=otrcut		# Benutzer der zum Bewerten benutzt wird
player=mplayer	# Mit diesem Player wird das Video wiedergegeben sofern $play auf yes steht
smart=yes		# Force-Smart fuer avidemux verwenden
vidcodec=copy	# Input-Video nur kopieren.
personal=no		# Persoenliche URL von cutlist.at zum Bewerten benutzen
ad_version=new	# New= Avidemux >=2.5, Old= Avidemux <=2.4
copy=no			# Wenn $toprated=yes, und keine Cutlist gefunden wird, $film nach $output kopieren

# Diese Variablen werden vom Benutzer gesetzt.
# Sie sind fuer die Verwendung des Decoders gedacht.
email="" 				# Die EMail-Adresse mit der Sie bei OTR registriert sind
password=""				# Das Passwort mit dem Sie sich bei OTR einloggen
decoder=$(which otrdecoder)	# Pfad zum decoder. Z.B. /home/benutzer/bin/otrdecoder

# Diese Variablen werden vom Benutzer gesetzt.
personalurl=""			#Die persoenliche URL von cutlist.at


#######################################
# Verbose-Level for logging:
# 0: do not print anything to console  1: print only errors to console
# 2: print errors and info to console  3: print errors, info and debug logs to console
VERBOSE=1
LOGFILE=$appdir/OTRcut.log	# ??? sinnvoller Ort muss noch gefunden werden ????


# ??? ToDo: Ordner aus synOTR.conf uebernehmen
# delfolder="/volume1/xxxxxxx/#recycle"
if [ -f ~/.otrcut ]; then
	source ~/.otrcut
else
	echo "$0: Keine Config-Datei gefunden, benutze Standardwerte."
fi

##############################################################################
## allgemeine Funktionen
##############################################################################

#################################################
#Diese Funktion gibt die Hilfe aus
showhelp () {
cat <<EOT
OtrCut Version: $version

Dieses Script schneidet OTR-Dateien anhand der Cutlist von http://cutlist.at.
Es koennen entweder die Tools avidemux oder avisplit/avimerge benutzt werden.
Avidemux kann im Gegensatz zu avisplit auch zwischen Keyframes schneiden.
Hier die Anwendung:

$0 [optionen] -i film.mpg.avi

Optionen:

-i, --input [arg]	Input Datei/Dateien (kann mehrfach benutzt werden um mehrere Dateien zu schneiden)

-a, --avisplit		Avisplit und avimerge anstelle von avidemux verwenden

-e, --error		Bei Fehlern das Script beenden

--tmp [arg]		TMP-Ordner angeben (Standard: /tmp/), In diesem Ordner wird noch ein Ordner "otrcut" angelegt, ACHTUNG: ALLE Daten in \$tmp werden geloescht!!!

-l, --local 		Lokale Cutlists verwenden (Cutlists werden im aktuellen Verzeichnis gesucht)

--delete		Quellvideo nach Schneidevorgang loeschen ACHTUNG: Falls es sich bei der Quelle um ein OtrKey handelt wird dies auch geloescht!!!

-o, --output [arg]	Ausgabeordner waehlen (Standard "./cut")

-ow, --overwrite	Schon existierende Ausgabedateien ueberschreiben

-b, --bewertung		Bewertungsfunktion aktivieren

-p, --play		Zusammen mit "-b, --bewertung" einsetzbar, startet vor dem Bewerten das Video in einem Videoplayer (Wird in der Variablen \$player definiert)

-w, --warn		Warnung bezueglich Loeschung aller Dateien in \$tmp unterdruecken

--toprated		Verwendet die best bewertetste Cutlist

-v, --verbose		Ausfuehrliche Ausgabe von avidemux bzw. avimerge/avisplit aktivieren

--nosmart		So wird das --force-smart-Argument fuer avidemux abgeschaltet.

--personal		Die persoenliche ID von cutlist.at zum Bewerten benutzen

-av, --avidemux		Bei Verwendung von Avidemux <=2.4 muss diese Schalter gesetzt werden.

-c, --copy		Wenn $toprated=yes, und keine Cutlist gefunden wird, $film nach $output kopieren

--vcodec [arg]		  Videocodec (avidemux) spezifizieren. Wenn nicht gesetzt, dann "copy". Moegliche Elemente fuer [arg]: Divx/Xvid/FFmpeg4/VCD/SVCD/DVD/XVCD/XSVCD/COPY

-u, --update		Nach einer neuen Version von OtrCut suchen

-h, --help		Diese Hilfe

-del Ordner fuer die geloeschten Dateien

Author: Daniel Siegmanski
Homepage: http://www.siggimania4u.de
Cutlists: http://www.cutlist.de, http://www.cutlist.at

Danke an MKay fuer das Aspect-Ratio-Script
FPS-Script/HD-Funktion: Florian Knodt <www.adlerweb.info>

EOT
exit 0
} ## END showhelp ##


#################################################
# Informiert Benutzer, ggf. ueber versch. Kanaele
senduserinfo () {
	if [ -z "$1" ]; then echo  "senduserinfo: ohne Information aufgerufen" |tee -a $LOGFILE; return ; fi
	if [ $dsmtextnotify = "on" ] ; then
		/usr/syno/bin/synodsmnotify @administrators "synOTR" "$1"
	fi
	if [ $dsmbeepnotify = "on" ] ; then echo 2 > /dev/ttyS1 ; fi ## short beep
} ## END senduserinfo ##


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
#Diese Funktion sucht nach einer neuen Version von OtrCut
update () {
	online_version=$(wget -q -O - http://otrcut.siggimania4u.de/version | /usr/bin/tr -d "\r")
	#online_version="0.0" ## URL funktioniert nicht mehr
	if [ "$online_version" -gt "$version" ]; then
		echo -e "Es ist eine neue Version verfuegbar."
		echo -e "Verwendete Version: $version "
		echo -e "Aktuelle Version: $online_version "
		echo "Die neue Version kann unter \"http://otrcut.siggimania4u.de\" heruntergeladen werden."
	else
		echo -e "Es wurde keine neuere Version gefunden."
	fi

	exit 0
} ## END update ##



#################################################
#Diese Funktion gibt die Warnung bezueglich der Loeschung von $tmp aus
loeschwarnung () {
	if [ "$warn" == "yes" ]; then
		echo -e ""
		echo "ACHTUNG!!!"
		echo "Das Script wird alle Dateien in $tmp/otrcut loeschen!"
		echo "Sie haben 5 Sekunden um das Script ueber STRG+C abzubrechen"
		i=0;
		while [ $i -lt 6 ]; do i=$(( i + 1 )); echo -n "$i " ; sleep 1 ; done
		echo -e "\n\n\n"
	fi
} ## END loeschwarnung ##


#################################################
#Diese Funktion gibt einen Hinweis zur Dateinamensuebergabe aus
dateihinweis () {
	echo -e ""
	echo "ACHTUNG!!!"
	echo "Die Eingabedateien muessen entweder ohne fuehrende Verzeichnise "
	echo "(z.B. datei.avi, nur wenn Datei im aktuellen Verzeichnis!) oder"
	echo "mit dem KOMPLETTEN Pfad (z.B. /home/user/datei.avi) angegeben werden!"
	echo -e ""
	echo ""
	echo ""
	sleep 2
} ## END dateihinweis ##


#################################################
# Diese Funktion ueberprueft verschiedene Einstellungen
# ??? einige Checks muessen nur einmalig erfolgen -- Checks verlagern ???
checkENV () {
	#Hier wird ueberprueft ob eine Eingabedatei angegeben ist
	if [ -z "$i" ]; then
		echo "Es wurde keine Eingabedatei angegeben!"
		exit 1
	fi
	# Ueberpruefe ob angegebene Datei existiert
	if [ ! -f "$i" ]; then
		echo -e "Eingabedatei nicht gefunden!"
		exit 1
	fi
	#Hier wird ueberprueft ob die Option -p, --play richtig gesetzt wurde ### ??? dieser Check gehoert zum globalen Check ###
	if [ "$play" == "yes" ] && [ "$bewertung" == "no" ]; then
		echo -e "\"Play\" kann nur in Verbindung mit \"Bewertung\" benutzt werden."
		exit 1
	fi

	# Hier wird ueberprueft ob der Standard-Ausgabeordner verwendet werden soll.
	# Wenn ja, wird ueberprueft ob er verfuegbar ist, wenn nicht wird er erstellt.
	# Wurde ein alternativer Ausgabeordner gewaehlt, wird geprueft ob er vorhanden ist.
	# Ist er nicht vorhanden wird gefragt ob er erstellt werden soll.
	if [ "$output" == "cut" ]; then
		if [ ! -d "cut" ]; then
			if [ -w $PWD ]; then
				mkdir cut
				echo "Verwende $PWD/cut als Ausgabeordner"
			else
				echo -e "Sie haben keine Schreibrechte im aktuellen Verzeichnis ($PWD)."
				exit 1
			fi
		fi
	else
		if [ -d "$output" ] && [ -w "$output" ]; then
			echo "Verwende $output als Ausgabeordner."
		elif [ -d "$output" ] && [ ! -w "$output" ]; then
			echo -e "Sie haben keine Schreibrechte in $output."
			exit 1
		else
			echo -e "Das Verzeichnis $output wurde nicht gefunden, soll er erstellt werden? [y|n]"
			read OUTPUT
			while [ "$OUTPUT" == "" ] || [ ! "$OUTPUT" == "y" ] && [ ! "$OUTPUT" == "n" ]; do #Bei falscher Eingabe
				echo -e "Falsche Eingabe, bitte nochmal:"
				read OUTPUT
			done
			if [ "$OUTPUT" == "n" ]; then	#Wenn der Benutzer nein "sagt"
				echo "Ausgabeverzeichnis \"$output\" soll nicht erstellt werden."
				exit 1
			elif [ "$OUTPUT" == "y" ]; then	#Wenn der Benutzer ja "sagt"
				echo -n "Erstelle Ordner $output -->"
				mkdir "$output"
				if [ -d "$output" ]; then
					echo -e "okay"
				else
					echo -e "false"
					exit 1
				fi
			fi
		fi
	fi

	#Hier wird ueberprueft ob der Standard-Tmpordner verwendet werden soll.
	#Wenn ja, wird ueberprueft ob er verfuegbar ist, wenn nicht wird er erstellt.
	#Wurde ein alternativer Tmpordner gewaehlt, wird geprueft ob er vorhanden ist.
	#Ist er nicht vorhanden wird gefragt ob er erstellt werden soll.
	if [ "$tmp" == "/tmp/otrcut" ]; then
		if [ ! -d "/tmp/otrcut" ]; then
			if [ -w /tmp ]; then
				mkdir "/tmp/otrcut"
				echo "Verwende $tmp als Ausgabeordner"
				#tmp="$tmp/otrcut"
			else
				echo -e "Sie haben keine Schreibrechte in /tmp/ ${end}"
				exit 1
			fi
		fi
	else
		if [ -d "$tmp" ] && [ -w "$tmp" ]; then
			mkdir "$tmp/otrcut"
			echo "Verwende $tmp/otrcut als Ausgabeordner."
			tmp="$tmp/otrcut"
		elif [ -d "$tmp" ] && [ ! -w "$tmp" ]; then
			echo -e "Sie haben keine Schreibrechte in $tmp!${end}"
		else
			echo -e "$tmp wurde nicht gefunden, soll er erstellt werden? [y|n]${end}"
			read TMP	#Lesen der Benutzereingabe nach $TMP
			while [ "$TMP" == "" ] || [ ! "$TMP" == "y" ] && [ ! "$TMP" == "n" ]; do	#Bei falscher Eingabe
				echo -e "Falsche Eingabe, bitte nochmal:${end}"
				read TMP	#Lesen der Benutzereingabe nach $TMP
			done
			if [ $TMP == n ]; then	#Wenn der Benutzer nein "sagt"
				echo "Tempverzeichnis \"$tmp\" soll nicht erstellt werden."
				exit 1
			elif [ $TMP == y ]; then	#Wenn der Benutzer ja "sagt"
				echo -n "Erstelle Ordner $tmp --> "
				mkdir "$tmp/otrcut"
				if [ -d "$tmp/otrcut" ]; then
					echo -e "okay${end}"
					tmp="$tmp/otrcut"
				else
					echo -e "false${end}"
					exit 1
				fi
			fi
		fi
	fi
} ## END checkENV ##


#################################################
#Diese Funktion ueberprueft ob avidemux installiert ist
check_software () {
	if [ "$UseAvidemux" == "yes" ]; then
		for s in avidemux2_cli avidemux2_qt4 avidemux2_gtk avidemux2 avidemux; do
			if [ -z "$CutProg" ]; then
				echo -n "Überpruefe ob $s installiert ist --> "
				if type -t $s >> /dev/null; then
					echo -e "okay"
					CutProg="$s"
				else
					echo -e "false"
				fi
			fi
		done
		if [ -z "$CutProg" ]; then
			echo -e "Bitte installieren sie avidemux, oder verwenden sie die Optione \"-a\"!"
			exit 1
		fi
	fi

	#Hier wird ueberprueft ob avisplit und avimerge installiert sind
	if [ "$UseAvidemux" == "no" ]; then
		for p in $appdir/bin/avisplit $appdir/bin/avimerge; do
			echo -n "Ueberpruefe ob $p installiert ist --> "
			#if type -t $p >> $appdir/bin; then
			if type -t $p >> /dev/null; then
				echo -e "okay"
				CutProg="avisplit"
			else
				echo -e "false"
				echo -e "Installieren Sie transcode!"
				exit 1
			fi
		done
	fi

	#Hier wird ueberprueft ob date zum umrechnen der Zeit benutzt werden kann
	echo -n "Ueberpruefe welche Methode zum Umrechnen der Zeit benutzt wird --> "
	date_var=$(date -u -d @120 +%T 2>/dev/null)
	if [ "$date_var" == "00:02:00" ]; then
		echo -e "date"	 ; date_okay=yes
	else
		echo -e "intern" ; date_okay=no
	fi

	#Hier wird ueberprueft ob der richtige Pfad zum Decoder angegeben wurde
	if [ "$decoded" == "yes" ]; then
		echo -n "Ueberpruefe ob der Decoder-Pfad richtig gesetzt wurde --> "
		if $decoder -v >> /dev/null; then
			echo "okay"
		else
			echo "false"
			exit 1
		fi
	if [ "$email" == "" ]; then
		echo "EMail-Adresse wurde nicht gesetzt."
		exit 1
	fi
	if [ "$password" == "" ]; then
		echo "Passwort wurde nicht gesetzt."
		exit 1
	fi
fi
} ## END check_software ##



#################################################
# Diese Funktion definiert den Cutlist- und Dateinamen und ueperprueft um
# welches Dateiformat es sich handelt
setoutputfile () {
	film=$i	#Der komplette Filmname und gegebenfalls der Pfad
	film_ohne_anfang=$i
	#Fuer Avidemux <=2.5 muss der komplette Pfad angegeben werden
	if [ "$ad_version" == "new" ]; then
		film_var=${film#/}
		output_var=${output#/}
		if [ "$film" == "$film_var" ]; then
			film_new_ad="$PWD/$film"
		else
			film_new_ad="$film"
		fi
		if [ "$output" == "$output_var" ]; then
			output="$PWD/$output"
		fi
	fi
	if [ "$decoded" == "yes" ]; then
		film_ohne_anfang="${film_ohne_anfang%%.otrkey}"
		film_ohne_anfang="${film_ohne_anfang##*/}"
		film="$film_ohne_anfang"
	fi
	CUTLIST=`basename "$film"`	#Filmname ohne Pfad
	echo -n "Ueberpruefe um welches Aufnahmeformat es sich handelt --> "
	if echo "$film_ohne_anfang" | grep -q ".HQ."; then	#Wenn es sich um eine "HQ" Aufnahme handelt
		film_ohne_ende=${film%%.mpg.HQ.avi}	#Filmname ohne Dateiendung
		CUTLIST=${CUTLIST/.avi/}.cutlist	#Der lokale Cutlistname
		format=hq
		echo -e "HQ"
	elif echo "$film_ohne_anfang" | grep -q ".mp4"; then	#Wenn es sich um eine "mp4" Aufnahme handelt
		film_ohne_ende=${film%%.mpg.mp4}	#Filmname ohne Dateiendung
		format=mp4
		CUTLIST=${CUTLIST/.mp4/}.cutlist	#Der lokale Cutlistname
		echo -e "mp4"
	else
		film_ohne_ende=${film%%.mpg.avi}	#Filmename ohne Dateiendung
		format=avi
		CUTLIST=${CUTLIST/.avi/}.cutlist	#Der lokale Cutlistname
		echo -e "avi"
	fi

	if echo "$film" | grep / >> /dev/null; then	#Wenn der Dateiname einen Pfad enthaelt
		film_ohne_anfang=${film##*/}	#Filmname ohne Pfad
		if echo "$film_ohne_anfang" | grep -q ".HQ."; then	#Wenn es sich um eine "HQ" Aufnahme handelt
			film_ohne_ende=${film_ohne_anfang%%.mpg.HQ.avi}
			format=hq
		elif echo "$film_ohne_anfang" | grep -q ".mp4"; then	#Wenn es sich um eine "mp4" Aufnahme handelt
			film_ohne_ende=${film_ohne_anfang%%.mpg.mp4}
			format=mp4
		else
			film_ohne_ende=${film_ohne_anfang%%.mpg.avi}
			format=avi
		fi
	fi

	if echo "$film_ohne_anfang" | grep -q ".HQ."; then
	   outputfile="$output/$film_ohne_ende.HQ-cut.avi"
	elif echo "$film_ohne_anfang" | grep -q ".mp4"; then
	   outputfile="$output/$film_ohne_ende-cut.mp4"
	else
	   outputfile="$output/$film_ohne_ende-cut.avi"
	fi
} ## END setoutputfile  ##


#################################################
#In dieser Funktion wird geprueft, ob die Cutlist okay ist
test_cutlist () {
	cutlist_size=$(ls -l "$tmp/$CUTLIST" | awk '{ print $5 }')
	if [ "$cutlist_size" -lt "100" ]; then
		cutlist_okay=no
		rm -rf "$TMP/$CUTLIST"
	else
		cutlist_okay=yes
	fi
} ## END test_cutlist ##


#################################################
# In dieser Funktion wird die lokale Cutlist ueberprueft
getlocalcutlist () {
	#echo "DEBUG: getlocalcutlist: $(pwd) -- Weiter mit RETURN"; read
	local_cutlists=$(ls *.cutlist 2>/dev/null)	#Variable mit allen Cutlists in $PWD
	match_cutlists=""	## passende Cutlisten zum Film
	filesize=$(ls -l "$film" | awk '{ print $5 }') #Dateigroesse des Filmes
	goodCount=0		## Anzahl Treffer
	vorhanden=no	## nehme erstmal an, es wurde keine Cutlist gefunden
	continue=1
	## Check, ob ueberhaupt cut-Listen vorhanden sind:
	if [ -z "$local_cutlists" ]; then 
		echo -e "Keine einzige *.cutlist Datei gefunden!"
		if [ "$HaltByErrors" == "yes" ]; then exit 1 ; fi
	fi

	echo -n "Ueberpruefe ob eine der gefundenen Cutlists zum Film passt --> "
	for f in $local_cutlists; do
		OriginalFileSize=$(cat $f | grep OriginalFileSizeBytes | cut -d"=" -f2 | /usr/bin/tr -d "\r")	#Dateigroesse des Films
		if cat "$f" | grep -q "$film"; then	#Wenn der Dateiname mit ApplyToFile uebereinstimmt
			echo -e -n "ApplyToFile "
			goodCount=$(( goodCount + 1 ))
			match_cutlists="$match_cutlists $f"
		fi
		# Wenn die Dateigroesse mit OriginalFileSizeBytes uebereinstimmt
		if [ "$OriginalFileSize" == "$filesize" ]; then
			echo -e -n "OriginalFileSizeBytes"
			goodCount=$(( goodCount + 1 ))
			match_cutlists="$match_cutlists $f"
		fi
	done

	# Wenn nur eine Cutlist gefunden wurde
	if [ "$goodCount" -eq 1 ]; then
		echo "Es wurde genau eine passende Cutlist gefunden. Diese wird nun verwendet."
		CUTLIST=$(echo $match_cutlists |sed -e 's/^\s+//')
		cp "$CUTLIST" "$tmp/"
		vorhanden=yes
		continue=0
	fi
	# Wenn mehrere Cutlists gefunden wurden
	if [ "$goodCount" -gt 1 ]; then
		echo "Es wurden $goodCount Cutlists gefunden. Bitte waehlen Sie aus:"
		echo ""
		number=0
		for f in $match_cutlists; do
			number=$(( number + 1 ))
			echo "$number: $f"
		done
		echo -n "Bitte die Nummer der zu verwendenden Cutlist eingeben: "
		read NUMBER
		while [ "$NUMBER" -gt "$goodCount" ]; do
			echo "false. Noch mal:"
			read NUMBER
		done
		number=0
		for f in $match_cutlists; do
			number=$(( number + 1 ))
			if [ "$NUMBER" == "$number" ]; then CUTLIST="$f"; fi
		done
		echo "Verwende $CUTLIST als Cutlist."
		cp "$CUTLIST" "$tmp/"
		vorhanden=yes
		continue=0
	fi
} ## END getlocalcutlist ##

#################################################
# In dieser Funktion wird versucht eine Cutlist aus den Internet zu laden
getcutlist () {
	if [ "$personal" == "yes" ]; then
		server=$personalurl
	else
		server="http://cutlist.at/"
	fi
	
	echo -e "Bearbeite folgende Datei: $film"
	if [ "$decoded" == "yes" ]; then
		filesize=$(ls -l "$output/$film" | awk '{ print $5 }')
	else
		filesize=$(ls -l "$film" | awk '{ print $5 }')
	fi
	##echo "getcutlist: filesize = $filesize"
	
	echo -n "Fuehre Suchanfrage anhand der Dateigroesse '$filesize' bei '$server' durch ---> "
	wget -q -O "$tmp/search.xml" "${server}getxml.php?version=0.9.8.0&ofsb=$filesize"
	rc=$?
	if [ $rc -gt 0 ]; then
		echo ""
		echo "getcutlist: beim Holen der cutlist vom Server '$server' trat ein Fehler (rc=$rc) auf --> Abbruch"
		echo ""
		exit 1
	fi
	# Check, ob ueberhaupt cutlisten in der search.xml enthalten sind
	if ! grep -q '<id>' "$tmp/search.xml"; then
		echo "Keine cutlist anhand der Dateigroesse '$filesize' gefunden!"
		## Alternative Suchanfrage ueber Dateinamen
		filmdateiname=`basename $film`
		echo -n "Fuehre Suchanfrage anhand des Dateinamens '$filmdateiname' bei '$server' durch ---> "
		wget -q -O "$tmp/search.xml" "${server}getxml.php?version=0.9.8.0&name=$filmdateiname"
		if [ $rc -gt 0 ]; then
			echo ""
			echo "getcutlist: beim Holen der cutlist vom Server '$server' trat ein Fehler (rc=$rc) auf --> Abbruch"
			echo ""
			exit 1
		fi
		if ! grep -q '<id>' "$tmp/search.xml"; then
			echo ""
			echo "Keine cutlist anhand des Dateinamens'$filmdateiname' gefunden!"
			echo ""
			exit 1
		fi
	fi
	
	array=0
	cutlist_anzahl=$(grep -c '/cutlist' "$tmp/search.xml" | /usr/bin/tr -d "\r") #Anzahl der gefundenen Cutlists
	if [ "$cutlist_anzahl" -ge "1" ] && [ "$continue" == "0" ]; then #Wenn mehrere Cutlists gefunden wurden
		echo ""
		tail=1
		while [ "$cutlist_anzahl" -gt "0" ]; do
				#Name der Cutlist
				name[$array]=$(grep "<name>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Author der Cutlist
				author[$array]=$(grep "<author>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Bewertung des Authors
				ratingbyauthor[$array]=$(grep "<ratingbyauthor>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Bewertung der User
				rating[$array]=$(grep "<rating>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Kommentar des Authors
				comment[$array]=$(grep "<usercomment>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#ID der Cutlist
				ID[$array]=$(grep "<id>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Anzahl der Bewertungen
				ratingcount[$array]=$(grep "<ratingcount>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Cutangaben in Sekunden
				cutinseconds[$array]=$(grep "<withtime>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Cutangaben in Frames (besser)
				cutinframes[$array]=$(grep "<withframes>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")
				#Filename der Cutlist
				filename[$array]=$(grep "<filename>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | /usr/bin/tr -d "\r")

			## interaktive cutlist-Auswahl 
			if [ "$toprated" == "no" ]; then #Wenn --toprated nicht gesetzt ist
				if echo $cutlistWithError | grep -q "${ID[$array]}"; then #Wenn Fehler gesetzt ist z.B. EPG-Error oder MissingBeginning
					echo -ne ""
				fi
				echo -n "[$array]"
				echo " Name: ${name[$array]}"
				echo " Author: ${author[$array]}"
				echo " Rating by Author: ${ratingbyauthor[$array]}"
				if [ -z "$cutlistWithError" ]; then
					echo -ne ""
				fi
				echo " Rating by Users: ${rating[$array]} @ ${ratingcount[$array]} Users"
				if [ -z "$cutlistWithError" ]; then
					echo -ne ""
				fi
				if [ "${cutinframes[$array]}" == "1" ]; then
					echo " Cutangabe: Als Frames"
				fi
				if [ "${cutinseconds[$array]}" == "1" ] && [ ! "${cutinframes[$array]}" == "1" ]; then
					echo " Cutangabe: Als Zeit"
				fi
				echo " Kommentar: ${comment[$array]}"
				echo " Filename: ${filename[$array]}"
				echo " ID: ${ID[$array]}"
				#echo " Server: ${server[$array]}"
				echo ""
				if echo $cutlistWithError | grep -q "${ID[$array]}"; then #Wenn Fehler gesetzt ist z.B. EPG-Error oder MissingBeginning
					echo ""
				fi
			fi
			tail=$((tail + 1))
			cutlist_anzahl=$((cutlist_anzahl - 1))
			array=$(( array + 1))
			array1=array
		done	
		## automatische cutlist-Auswahl
		if [ "$toprated" == "yes" ]; then # Wenn --toprated gesetzt wurde
				echo "Lade die Cutlist mit der besten User-Bewertung herunter."
				array1=$(( array1 - 1))
				while [ $array1 -ge 0 ]; do
					rating1[$array1]=${rating[$array1]}
					if [ "${rating1[$array1]}" == "" ]; then	#Wenn keine Benutzerwertung abgegeben wurde
						rating1[$array1]="0.00"	#Schreibe 0.00 als Bewertung
					fi
					rating1[$array1]=$(echo ${rating1[$array1]} | sed 's/\.//g')	#Entferne den Dezimalpunkt aus der Bewertung. 4.50 wird zu 450
					#echo "Rating ohne Komma: ${rating1[$array1]}"
					array1=$(( array1 - 1))
				done
				numvalues=${#rating1[@]}	#Anzahl der Arrays
				for (( i=0; i < numvalues; i++ )); do
					lowest=$i
					for (( j=i; j < numvalues; j++ )); do
						if [ ${rating1[j]} -ge ${rating1[$lowest]} ]; then
							lowest=$j
						fi
					done
					temp=${rating1[i]}
					rating1[i]=${rating1[lowest]}
					rating1[lowest]=$temp
				 done
				bigest=${rating1[0]}
	
				beste_bewertung=${bigest%%??}	#Die beste Wertung ohne Dezimalpunkt
				beste_bewertung_punkt=$beste_bewertung.${bigest##?}	#Die beste Wertung mit Dezimalpunkt
		fi
	fi
	
	if [ "$toprated" == "yes" ] && [ "$continue" == "0" ]; then
		bereits_toprated=no
		echo "Die beste Bewertung ist: $beste_bewertung"
		bereits_toprated=yes
	
		if [ "$beste_bewertung" == "0" ]; then beste_bewertung="</rating>" ; fi
	
		cutlist_nummer=$(grep "<rating>" "$tmp/search.xml" | grep -n "<rating>$beste_bewertung" | cut -d: -f1 | head -n1)
		id=$(grep "<id>" "$tmp/search.xml" | head -n$cutlist_nummer | tail -n1 | cut -d">" -f2 | cut -d"<" -f1) #ID der best bewertetsten Cutlist
		num=$(( cutlist_nummer - 1))
		id_downloaded=$(echo ${ID[$num]})
		CUTLIST=$(grep "<name>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | head -n$cutlist_nummer | tail -n1 | /usr/bin/tr -d "\r") #Name der Cutlist
	fi
	#	
	if [ "$toprated" == "no" ] && [ "$continue" == "0" ]; then
		array_groesse=$(( array - 1))
		CUTLIST_ZAHL=""
		while [ "$CUTLIST_ZAHL" == "" ]; do #Wenn noch keine Cutlist gewaehlt wurde
			echo -n "Bitte die Nummer der zu verwendenden Cutlist eingeben: "
			read CUTLIST_ZAHL #Benutzereingabe lesen
			if [ -z "$CUTLIST_ZAHL" ]; then
				echo -e "Ungueltige Auswahl."
				CUTLIST_ZAHL=""
			elif [ "$CUTLIST_ZAHL" -gt "$array_groesse" ]; then
				echo -e "Ungueltige Auswahl."
				CUTLIST_ZAHL=""
			fi
		done	
		CUTLIST_ZAHL=$(( CUTLIST_ZAHL + 1))
		id=$(grep "<id>" "$tmp/search.xml" | tail -n$CUTLIST_ZAHL | head -n1 | cut -d">" -f2 | cut -d"<" -f1)
		num=$(( CUTLIST_ZAHL - 1))
		id_downloaded=$(echo ${id[$num]})
		CUTLIST=$(grep "<name>" "$tmp/search.xml" | tail -n$CUTLIST_ZAHL | head -n1 | cut -d">" -f2 | cut -d"<" -f1)
	fi
	
	if [ "$continue" == "0" ]; then
		echo -n "Lade $CUTLIST -->"
		wget -q -O "$tmp/$CUTLIST" "${server}getfile.php?id=$id"
		test_cutlist # Testen der Cutlist
		if [ -f "$tmp/$CUTLIST" ] && [ "$cutlist_okay" == "yes" ]; then
			echo "okay"
			continue=0
		else
			echo "false"
		fi
	fi
} ## END getcutlist ##


#################################################
#Hier wird ueberprueft um welches Cutlist-Format es sich handelt
checkcutlist () {
	echo -n "Checke cutlist (Format oder ob Download OK)  --> "
	if cat "$tmp/$CUTLIST" | grep "StartFrame=" >> /dev/null; then
		echo "Frames"
		format=frames
	elif cat "$tmp/$CUTLIST" | grep "Start=" >> /dev/null; then
		echo "Zeit"
		format=zeit
	else
		echo "false"
		echo  "Wahrscheinlich wurde das Limit von Server '$server' ueberschritten!"
		exit 1
	fi
} ## END checkcutlist ##


#################################################
#Hier wir die Cutlist ueberprueft, auf z.B. EPGErrors, MissingEnding, MissingVideo, ...
cutlist_error () {
	#Diese Variable beinhaltet alle moeglichen Fehler
	errors="EPGError MissingBeginning MissingEnding MissingVideo MissingAudio OtherError"
	for e in $errors; do
		error_check=$(cat "$tmp/$CUTLIST" | grep -m1 $e | cut -d"=" -f2 | /usr/bin/tr -d "\r")
		if [ "$error_check" == "1" ]; then
			echo -e "Es wurde ein Fehler gefunden: \"$e\""
			error_yes=$e
			if [ "$error_yes" == "OtherError" ]; then
				othererror=$(cat "$tmp/$CUTLIST" | grep "OtherErrorDescription")
				othererror=${othererror##*=}
				echo -e "Grund fuer \"OtherError\": \"$othererror\""
			fi
			if [ "$error_yes" == "EPGError" ]; then
				epgerror=$(cat "$tmp/$CUTLIST" | grep "ActualContent")
				epgerror=${epgerror##*=}
				echo -e "ActualContent: $epgerror${end}"
			fi
			error_found=1
			cutlistWithError="${cutlistWithError} $id_downloaded"
			#echo $cutlistWithError
		fi
	done
} ## END cutlist_error ##

#################################################
#Hier wird geprueft, welches Seitenverhaeltnis der Film hat.
#Danke hierfuer an MKay aus dem OTR-Forum
aspectratio () {
	echo -n "Ermittles Seitenverhaeltnis --> "

	aspectR=$(
		mplayer -vo null -nosound "$film" 2>&1 |
		while read line; do				# Warten bis mplayer aspect-infos liefert oder anfaengt zu spielen
			if [[ $line == "Movie-Aspect is 1.33:1"* ]] || [[ "$line" == "Film-Aspekt ist 1.33:1"* ]]; then
				echo 1
				break
			fi
			if [[ $line == "Movie-Aspect is 0.56:1"* ]] || [[ "$line" == "Film-Aspekt ist 0.56:1"* ]]; then
				echo 2
				break
			fi
			if [[ $line == "Movie-Aspect is 1.78:1"* ]] || [[ "$line" == "Film-Aspekt ist 1.78:1"* ]]; then
				echo 2
				break
			fi
			if [[ $line == "VO: [null]"* ]] ; then
				echo 0
				break
			fi
		done
	)
	#echo $aspectR

	if [ "$aspectR" -eq 0 ] ; then
		echo -e "false"
		if [ "$smart" == "no" ]; then
			aspect=169
		else
			echo -n "Soll der 16:9-Modus verwendet werden? [y|N]? "
			read ASPECT
			if [ "$ASPECT" == "y" ]; then
				aspect=169
				echo "Benutze 16:9-Modus"
			else
				aspect=43
				echo "Benutze den normalen Modus."
			fi
		fi
	fi
	if [ $aspectR -eq 1 ] ; then
		echo -e "4:3"
		aspect=43
	fi
	if [ $aspectR -eq 2 ] ; then
		echo -e "16:9"
		aspect=169
	fi
} ## END aspectratio ##



#################################################
#Hier wird geprueft, welche Bildrate der Film hat.
get_fps () {
	fps=50	## Defaultwert
	if file "$film" 2>&1 | grep "25.00 fps" > /dev/null ; then
		fps=25
	fi
	echo "Ermittelte Bildrate --> $fps"
} ## END get_fps ##



#################################################
#Hier wird nun die Zeit ins richtige Format fuer avisplit umgerechnet
time1 () {
	time=""
	cut_anzahl=$(cat "$tmp/$CUTLIST" | grep "NoOfCuts" | cut -d"=" -f2 | /usr/bin/tr -d "\r")
	echo "####Auflistung der Cuts####"

	# Wenn das verwendete Format "Zeit" ist:
	# 	In der Variable $time sind alle Cuts wie folgt aufgelistet:
	# 	hh:mm:ss-hh:mm:ss,hh:mm:ss-hh:mm:ss,...
	if [ "$format" == "zeit" ]; then
		head1=1
		echo "Es muessen $cut_anzahl Cuts umgerechnet werden."
		while [ "$cut_anzahl" -gt "0" ]; do
			#Die Sekunde in der der Cut beginnen soll
			time_seconds_start=$(cat "$tmp/$CUTLIST" | grep "Start=" | cut -d"=" -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | /usr/bin/tr -d "\r")
			echo "Startcut: $time_seconds_start. Sekunde"
			time=${time}$(date -u -d @$time_seconds_start +%T-)	#Die Sekunden umgerechned in das Format hh:mm:ss
			#Wie viele Sekunden der Cut dauert
			time_seconds_ende=$(cat "$tmp/$CUTLIST" | grep "Duration=" | cut -d"=" -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | /usr/bin/tr -d "\r")
			time_seconds_ende=$(( time_seconds_ende + time_seconds_start )) #Die Sekunde in der der Cut endet
			echo "Endcut: $time_seconds_ende. Sekunde"
			time=${time}$(date -u -d @$time_seconds_ende +%T,)	#Die Endsekunde im Format hh:mm:ss
			head1=$(( head1 + 1 ))
			cut_anzahl=$(( cut_anzahl - 1 ))
		done
	fi
	# Wenn das verwendete Format "Frames" ist:
	# 	In der Variable $time sind alle Cuts wie folgt aufgelistet:
	# 	StartFrame-EndFrame,StartFrame-EndFrame,...
	if [ "$format" == "frames" ]; then
		head1=1
		echo "Es muessen $cut_anzahl Cuts umgerechnet werden."
		while [ $cut_anzahl -gt 0 ]; do
			# Der Frame bei dem der Cut beginnt
			startframe=$(cat "$tmp/$CUTLIST" | grep "StartFrame=" | cut -d= -f2 | head -n$head1 | tail -n1 | /usr/bin/tr -d "\r")
			echo "Startframe= $startframe"
			time="${time}$startframe-"
			# Wie viele Frames dauert der Cut
			stopframe=$(cat "$tmp/$CUTLIST" | grep "DurationFrames=" | cut -d= -f2 | head -n$head1 | tail -n1 | /usr/bin/tr -d "\r")
			stopframe=$(( stopframe + startframe ))	# Der Frame bei dem der Cut endet
			echo "Endframe= $stopframe"
			time="${time}$stopframe,"	# Auflistung aller Cuts
			head1=$(( head1 + 1 ))
			cut_anzahl=$(( cut_anzahl - 1 ))
		done
	fi
	echo "####ENDE####"
} ## END time1  ##

#################################################
#Hier wird nun die Zeit ins richtige Format fuer avisplit umgerechnet, falls die date-Variante nicht funktioniert
time2 () {
	time=""
	cut_anzahl=$(cat "$tmp/$CUTLIST" | grep "NoOfCuts" | cut -d= -f2 | /usr/bin/tr -d "\r")
	echo "#####Auflistung der Cuts#####"
	#########################
	if [ $format == "zeit" ]; then
		head1=1
	   	echo "Es muessen $cut_anzahl Cuts umgerechnet werden"
	   	while [ $cut_anzahl -gt 0 ]; do
			#Die Sekunde in der der Cut startet
		  	time_seconds_start=$(cat "$tmp/$CUTLIST" | grep "Start=" | cut -d= -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | /usr/bin/tr -d "\r")
		  	ss=$time_seconds_start	#Setze die Skunden auf $time_seconds_start
		  	mm=0	#Setze die Minuten auf 0
		  	hh=0	#Setze die Stunden auf 0
		  	while [ $ss -ge "60" ]; do	#Wenn die Sekunden >= 60 sind
				mm=$(( mm +  1))		#Zaehle Minuten um 1 hoch
				ss=$(( ss - 60))	#Zaehle Sekunden um 60 runter
			 	while [ $mm -ge "60" ]; do	#Wenn die Minuten >= 60 sind
					hh=$(( hh +  1 ))	#Zaehle Stunden um 1 hoch
					mm=$(( mm - 60 ))	#Zaehle Minuten um 60 runter
			 	done
		  	done
		  	time2_start=$hh:$mm:$ss	#Bringe die Zeit ins richtige Format
		  	echo "Startcut= $time2_start"
		  	time="${time}${time2_start}-"	#Auflistung aller Zeiten
			#Sekunden wie lange der Cut dauert
		  	time_seconds_ende=$(cat "$tmp/$CUTLIST" | grep "Duration=" | cut -d= -f2 | head -n$head1 | tail -n1 | cut -d"." -f1 | /usr/bin/tr -d "\r")
			time_seconds_ende=$(( time_seconds_ende + time_seconds_start))	#Die Sekunde in der der Cut endet
		  	ss=$time_seconds_ende	#Setze die Sekunden auf $time_seconds_ende
		  	mm=0	#Setze die Minuten auf 0
		  	hh=0	#Setze die Stunden auf 0
		  	while [ $ss -ge "60" ]; do	#Wenn die Sekunden >= 60 sind
				mm=$(( mm +  1 ))	#Zaehle Minuten um 1 hoch
				ss=$(( ss - 60 ))	#Zaehle Sekunden um 60 runter
			 	while [ $mm -ge "60" ]; do	#Wenn die Minuten >= 60 sind
					hh=$(( hh +  1 ))	#Zaehle Stunden um 1 hoch
					mm=$(( mm - 60 ))	#Zaehle Minuten um 60 runter
				done
			done
		  	time2_ende=$hh:$mm:$ss	#Bringe die Zeit ins richtige Format
		  	echo "Endcut= $time2_ende"
		  	time="${time}${time2_ende},"	#Auflistung alles Zeiten
			head1=$(( head1 + 1 ))
			cut_anzahl=$(( cut_anzahl - 1 ))
	   	done
	fi ## END if Zeit.... ##
	#########################
	if [ $format == "frames" ]; then
		head1=1
		echo "Es muessen $cut_anzahl Cuts umgerechnet werden"
		while [ $cut_anzahl -gt 0 ]; do
			#Der Frame bei dem der Cut beginnt
			startframe=$(cat "$tmp/$CUTLIST" | grep "StartFrame=" | cut -d= -f2 | head -n$head1 | tail -n1 | /usr/bin/tr -d "\r")
			echo "Startframe= $startframe"
			time="${time}$startframe-"	#Auflistung der Cuts
			#Die Frames wie lange der Cut dauert
			stopframe=$(cat "$tmp/$CUTLIST" | grep "DurationFrames=" | cut -d= -f2 | head -n$head1 | tail -n1 | /usr/bin/tr -d "\r")
			stopframe=$(( stopframe + startframe))	#Der Frame bei dem der Cut endet
			echo "Endframe= $stopframe"
			time="${time}$stopframe,"	#Auflistung der Cuts
			head1=$(( head1 + 1 ))
			cut_anzahl=$(( cut_anzahl - 1 ))
		done
	fi
	echo "#####ENDE#####"
} ## END time2 ##

#################################################
#Hier wird nun, falls aviplit/avimerge gewaehlt wurde, avisplit und avimerge gestartet
do_split_merge () {
	echo "Uebergebe die Cuts an avisplit/avimerge"
	if [ $decoded == "yes" ]; then
		#Hier wird avisplit gestartet, avimerge wird on-the-fly ueber den Parameter -c gestartet
		$appdir/bin/nice -n 15 $appdir/bin/avisplit -i "$output/$film" -o "$outputfile" -t $time -c
	else
		#Hier wird avisplit gestartet, avimerge wird on-the-fly ueber den Parameter -c gestartet
		$appdir/bin/nice -n 15 $appdir/bin/avisplit -i "$film" -o "$outputfile" -t $time -c
	fi
	if [ -f "$outputfile" ]; then
		echo -e "outputfile '$outputfile' wurde erstellt"
	
		# DSM Benachrichtigung:
		if [ "$OTRRENAMEACTIVE" == "on" ] ; then
				lastjob=4
			elif [ "$OTRAVI2MP4ACTIVE" == "on" ] ; then
				lastjob=3
			elif [ "$OTRCUTACTIVE" == "on" ] ; then
				lastjob=2
			else
				lastjob=1
		fi
		filedestname=`basename $outputfile`
		if [ $lastjob -eq 2 ] ; then
			if [ $dsmtextnotify = "on" ] ; then
				synodsmnotify @administrators "synOTR" "$filedestname ist fertig"
			fi
			if [ $dsmbeepnotify = "on" ] ; then
					echo 2 > /dev/ttyS1 #short beep
			fi
		fi
		if [ "$delete" == "yes" ]; then
			echo "Loesche Quellvideo."
			if [ $decoded == "yes" ]; then
				$appdir/bin/nice -n 15 rm -rf "$output/$film"
			else
				#$appdir/bin/nice -n 15 rm -rf "$film"
				$appdir/bin/nice -n 15 mv "$film" "$delfolder"
			fi
		fi
	else
		echo -e "Avisplit oder avimerge muss einen Fehler verursacht haben."
		if [ "$HaltByErrors" == "yes" ]; then
			exit 1
		else
			continue=1
		fi
	fi
} ## END do_split_merge ##


#################################################
#In dieser Funktion wird der Projektanfang definiert
# wird in demux verwendet ??? Rueckbau nach demux ???
start1 () {
cat << EOF
//AD <- Needed to identify//
var app = new Avidemux();

//** Video **
// 01 videos source
EOF
} ## END  ##

#################################################
# wird in demux verwendet ??? Rueckbau nach demux ???
start2 () {
cat << EOF
//$cut_anzahl segments
app.clearSegments();
EOF
} ## END  ##

#################################################
# wird in demux verwendet ??? Rueckbau nach demux ???
ende () {
fpsjs=$(($fps*1000))
cat << EOF

//** Postproc **
app.video.setPostProc(3,3,0);
app.video.setFps1000($fpsjs);

//** Filters **

//** Video Codec conf **
app.video.codec("$vidcodec","CQ=4","0 ");

//** Audio **
app.audio.reset();
app.audio.codec("copy",128,0,"");
app.audio.normalizeMode=0;
app.audio.normalizeValue=0;
app.audio.delay=0;
app.audio.mixer("NONE");
app.audio.scanVBR();
app.setContainer("AVI");
setSuccess(app.save("$outputfile"));
//app.Exit();

//End of script
EOF
} ## END ende  ##

#################################################
ende_new () {
fpsjs=$(($fps*1000))
cat << EOF

//** Postproc **
app.video.setPostProc(3,3,0);
app.video.fps1000=$fpsjs;

//** Filters **

//** Video Codec conf **
app.video.codec("$vidcodec","CQ=4","0 ");

//** Audio **
app.audio.reset();
app.audio.codec("copy",128,0,"");
app.audio.normalizeMode=0;
app.audio.normalizeValue=0;
app.audio.delay=0;
app.audio.mixer="NONE";
app.audio.scanVBR=""
app.setContainer="AVI";
setSuccess(app.save("$outputfile"));
//app.Exit();

//End of script
EOF
} ## END ende_new ##

#################################################
# Hier wird nun, fals avidemux gewaehlt wurde, avidemux gestartet
demux () {
	start1 >> "$tmp/avidemux.js"
	
	if [ "$ad_version" == "old" ]; then
		if [ "$decoded" == "yes" ]; then
			echo "app.load(\"$output/$film\")" >> "/$tmp/avidemux.js"
		else
			echo "app.load(\"$film\")" >> "/$tmp/avidemux.js"
		fi
	elif [ "$ad_version" == "new" ]; then
		if [ "$decoded" == "yes" ]; then
			echo "app.load(\"$output_new/$film\")" >> "/$tmp/avidemux.js"
		else
			echo "app.load(\"$film_new_ad\")" >> "/$tmp/avidemux.js"
		fi
	fi
	
	start2 >> "$tmp/avidemux.js"
	
	cut_anzahl=$(cat "$tmp/$CUTLIST" | grep "NoOfCuts" | cut -d= -f2 | /usr/bin/tr -d "\r")
	echo "#####Auflistung der Cuts#####"
	if [ "$format" = "zeit" ]; then
		head2=1
		echo "Es muessen $cut_anzahl Cuts umgerechnet werden"
		while [ "$cut_anzahl" -gt 0 ]; do
			time_seconds_start=$(cat "$tmp/$CUTLIST" | grep "Start=" | cut -d= -f2 | head -n$head2 | tail -n1 | cut -d"." -f1 | /usr/bin/tr -d "\r")
			time_frame_start=$(( time_seconds_start * fps))
			  	echo "Startframe= $time_frame_start"
			  	time_seconds_dauer=$(cat "$tmp/$CUTLIST" | grep "Duration=" | cut -d= -f2 | head -n$head2 | tail -n1 | cut -d"." -f1 | /usr/bin/tr -d "\r")
				time_frame_dauer=$(( time_seconds_dauer * fps))
			  	echo "Dauer= $time_frame_dauer"
			  	echo "app.addSegment(0,$time_frame_start,$time_frame_dauer);" >> "$tmp/avidemux.js"
				head2=$(( head2 + 1 ))
				cut_anzahl=$(( cut_anzahl - 1 ))
			done
	elif [ "$format" = "frames" ]; then
		head2=1
			echo "Es muessen $cut_anzahl Cuts umgerechnet werden"
			while [ $cut_anzahl -gt 0 ]; do
				startframe=$(cat "$tmp/$CUTLIST" | grep "StartFrame=" | cut -d= -f2 | head -n$head2 | tail -n1 | /usr/bin/tr -d "\r")
			  	echo "Startframe= $startframe"
			  	dauerframe=$(cat "$tmp/$CUTLIST" | grep "DurationFrames=" | cut -d= -f2 | head -n$head2 | tail -n1 | /usr/bin/tr -d "\r")
			  	echo "Dauer= $dauerframe"
			  	echo "app.addSegment(0,$startframe,$dauerframe);" >> "$tmp/avidemux.js"
				head2=$(( head2 + 1))
				cut_anzahl=$((cut_anzahl - 1))
			done
	fi
	
	echo "#####ENDE#####"
	
	if [ "$ad_version" == "old" ]; then
		if echo "$film_ohne_anfang" | grep -q ".HQ."; then
			outputfile="$output/$film_ohne_ende.HQ-cut.avi"
		elif echo "$film_ohne_anfang" | grep -q ".mp4"; then
	   		outputfile="$output/$film_ohne_ende-cut.mp4"
		else
	   		outputfile="$output/$film_ohne_ende-cut.avi"
		fi
	else
		if echo "$film_ohne_anfang" | grep -q ".HQ."; then
			outputfile="$output/$film_ohne_ende.HQ-cut.avi"
		elif echo "$film_ohne_anfang" | grep -q ".mp4"; then
	   		outputfile="$output/$film_ohne_ende-cut.mp4"
		else
	 	  	outputfile="$output/$film_ohne_ende-cut.avi"
		fi
	fi

	if [ "$ad_version" == "old" ]; then
		ende >> "$tmp/avidemux.js"
	else
		ende_new >> "$tmp/avidemux.js"
	fi
	
	echo "Uebergebe die Cuts nun an avidemux"
	#if [ "$aspect" == "43" ]; then
	if [ "$smart" == "yes" ]; then
		if [ "$verbose" == "yes" ]; then
			$appdir/bin/nice -n 15 $CutProg --nogui --force-smart --run "$tmp/avidemux.js" --quit
		else
			$appdir/bin/nice -n 15 $CutProg --nogui --force-smart --run "$tmp/avidemux.js" --quit >> /dev/null
		fi
	#elif [ "$aspect" == "169" ]; then
	elif [ "$smart" == "no" ]; then
		if [ "$verbose" == "yes" ]; then
			$appdir/bin/nice -n 15 $CutProg --nogui --run "$tmp/avidemux.js" --quit
		else
			$appdir/bin/nice -n 15 $CutProg --nogui --run "$tmp/avidemux.js" --quit >> /dev/null
		fi
	fi
	## Check, ob outputfile ordentlich generiert wurde
	if [ -f "$outputfile" ]; then
		echo -n -e  $outputfile
		 	echo -e " wurde erstellt"
		if [ "$delete" == "yes" ]; then
			echo "Loesche Quellvideo."
			if [ $decoded == "yes" ]; then
				$appdir/bin/nice -n 15 rm -rf "$output/$film"
			else
				#$appdir/bin/nice -n 15 rm -rf "$film"
				$appdir/bin/nice -n 15 mv "$film" "$delfolder/"
			fi
		fi
	else
		echo -e "Avidemux muss einen Fehler verursacht haben"
	  	exit 1
	fi
} ## END demux  ##


#################################################
#Hier wird nun, wenn gewuenscht, eine Bewertung fuer die Cutlist abgegeben
bewerte_cutlist () {
	echo ""
	echo "Sie koennen nun eine Bewertung fuer die Cutlist abgeben."
	echo "Folgende Noten stehen zur verfuegung:"
	echo "[0] Test (schlechteste Wertung)"
	echo "[1] Anfang und Ende geschnitten"
	echo "[2] +/- 5 Sekunden"
	echo "[3] +/- 1 Sekunde"
	echo "[4] Framegenau"
	echo "[5] Framegenau und keine doppelten Szenen"
	echo ""
	echo "Sollten Sie fuer diese Cutlist keine Bewertung abgeben wollen,"
	echo "druecken Sie einfach ENTER."
	echo -n "Note: "
	note=""
	read note
	while [ ! "$note" == "" ] && [ "$note" -gt "5" ]; do
		note=""
	 	echo -e "Ungueltige Eingabe, bitte nochmal:"
	  	read note
	done
	if [ "$note" == "" ]; then
		echo "Fuer diese Cutlist wird keine Bewertung abgegeben."
	else
		echo -n "Übermittle Bewertung fuer $CUTLIST -->"
		if [ "$personal" == "yes" ]; then
			wget -q -O "$tmp/rate.php" "${personalurl}rate.php?rate=$id&rating=$note&userid=$cutlistuser&version=0.9.8.7"
		else
			wget -q -O "$tmp/rate.php" "http://cutlist.at/rate.php?rate=$id&rating=$note&userid=$user&version=0.9.8.7"
		fi
		sleep 1
		if [ -f "$tmp/rate.php" ]; then
			if cat "$tmp/rate.php" | grep -q "Cutlist nicht von hier. Bewertung abgelehnt."; then
					echo -e " False"
		  			echo -e " Die Cutlist ist nicht von http://cutlist.at und kann nicht bewertet werden."
		   	elif cat "$tmp/rate.php" | grep -q "Du hast schon eine Bewertung abgegeben oder Cutlist selbst hochgeladen."; then
		   	   	echo -e " False"
			  		echo -e "Du hast fuer die Cutlist schonmal eine Bewertung abgegeben oder sie selbst hochgeladen."
			elif cat "$tmp/rate.php" | grep -q "Sie haben diese Liste bereits bewertet"; then
			  		echo -e " False"
			  		echo -e "Du hast fuer die Cutlist schonmal eine Bewertung abgegeben oder sie selbst hochgeladen."
		   	elif cat "$tmp/rate.php" | grep -q "Cutlist wurde bewertet"; then
			  		echo -e "Okay"
			  		echo -e "Cutlist wurde bewertet"
		   	fi
	   	else
		  	echo -e "False"
		  	echo -e "Bewertung fehlgeschlagen."
	   	fi
	fi
} ## END bewerte_cutlist ##



#################################################
# Hier wird ein Otrkey-File dekodiert, falls es gewuenscht ist
# ??? Fehlerhandling einbauen ???
decode_otrkey () {
	if [ -z "$1" ]; then echo "decode_otrkey: Dateiangabe fehlt --> Abbruch"; exit 1; fi
	OTRKEYDatei="$1"
	if echo $OTRKEYDatei | grep -q .otrkey; then
		if [ ! "$email_checked" == "yes" ]; then
			if [ "$email" == "" ]; then
				echo -e "Kann nicht dekodieren da keine EMail-Adresse angegeben wurde!"
				exit 1
			fi
			if [ "$password" == "" ]; then
				echo -e "Kann nicht dekodieren da kein Passwort angegeben wurde!"#
				exit 1
			fi
		else
			email_checked=yes
		fi
		echo "Decodiere Datei --> "
		$appdir/bin/nice -n 15 $decoder -e "$email" -p "$password" -q -f -i "$OTRKEYDatei" -o "$output"
		decoded=yes
	else
		decoded=no
	fi
	if [ "$delete" == "yes" ]; then echo "Loesche OtrKey" ; rm -rf "$OTRKEYDatei" ; fi
} ## END decode_otrkey ##


#################################################
# Hier werden die temporaeren Dateien geloesc
del_tmp () {
	if [ "$tmp" == "" ] || [ "$tmp" == "/" ] || [ "$tmp" == "/home" ]; then
		echo -e "Achtung, bitte ueberpruefen Sie die Einstellung von \$tmp"
		exit 1
	fi
	echo "Loesche temporaere Dateien in $tmp/"
	rm -rf "$tmp"/*	# ??? gefaehrlich, spezifischer angeben ???
} ## END del_tmp  ##


##############################################################################
## Check Parameter
## - Hier werden die uebergebenen Option ausgewertet
##############################################################################
while [ ! -z "$1" ]; do
	case $1 in
		-i | --input )	input="$input $2"
				shift ;;
		-a | --avisplit )	UseAvidemux=no ;;
		-e | --error )	HaltByErrors=yes ;;
		-d | --decode )	decode=yes ;;
		--delete )	delete=yes ;;
		-l | --local )	UseLocalCutlist=yes ;;
		-t | --tmp )	tmp=$2
				shift ;;
		-o | --output )	output=$2
				shift ;;
		-ow | --overwrite )	overwrite=yes ;;
		-v | --verbose )	verbose=yes ;;
		-p | --play )	play=yes ;;
		-b | --bewerten)	bewertung=yes ;;
		-w | --warn )	warn=no ;;
		-c | --copy )	copy=yes ;;
		--personal )	personal=yes ;;
		--toprated )	toprated=yes ;;
		--deldir ) 	delfolder=$2 ;;
		--lj ) 	lastjob=$2 ;;
		--wd ) 	synotrconf=$2 ;;
		--nosmart )	smart=no ;;
		--vcodec )	  vidcodec="$2"
								shift;;
		-av | --avidemux ) ad_version=old ;;
		-u | --update )	update ;;
		-h | --help )	showhelp ;;
	esac
	shift
done


# Konfiguration fuer synOTR sourcen:
. $synotrconf ### ??? noch besser verankern, z.B. fuer Standaloneaufruf
echo "detailierte Ausgabe aktiv: $verbose"






##############################################################################
#	Hauptprogramm ??? soll mal so sein, Code muss noch angepasst werden ???
##############################################################################
if [ "$warn" == "yes" ]; then loeschwarnung ; fi
dateihinweis # ??? nur wenn noetig oder ganz weg, bitte ueberarbeiten ###

#if [ "$server" == "0" ]; then
#   	echo "Verwende  http://cutlist.de als Server."
#elif [ "$server" == "1" ]; then
#   	echo "Verwende http://cutlist.at als Server"
#elif [ "$server" == "2" ]; then
#   	echo "Verwende http://cutlist.mbod.net als Server"
#fi
check_software	## ob vorhanden oder in welcher Version
for i in ${input}; do
	checkENV	## checkt: angegebene Datei, TMP- und cut-Verzeichnis
	del_tmp
	decode_otrkey $i
	setoutputfile
  	if [ "$UseLocalCutlist" == "yes" ]; then getlocalcutlist ; fi

   	while true; do
		if [ "$UseLocalCutlist" == "no" ] || [ "$vorhanden" == "no" ]; then getcutlist ; fi
		if [ "$continue" == "0" ]; then checkcutlist ; fi
		#if [ "$continue" == "0" ]; then aspectratio ; fi
		if [ "$continue" == "0" ]; then get_fps ; fi
		if [ "$continue" == "0" ]; then cutlist_error ; fi
		if [ "$error_found" == "1" ] && [ "$toprated" == "no" ]; then
			echo -e "${gelb}In der Cutlist wurde ein Fehler gefunden, soll sie verwendet werden? [y|n]${normal}"
			read error_antwort
			if [ "$error_antwort" == "y" ]; then
				echo -e "${gelb}Verwende die Cutlist trotz Fehler!${normal}"
				break
			else
				echo "Bitte neue Cutlist waehlen!"
			fi
		else
			break
		fi
		if [ "$error_found" == "1" ] && [ "$toprated" == "yes" ]; then break ; fi
	done
	if [ "$CutProg" = "avisplit" ] && [ $continue == "0" ]; then
	   	if   [ "$date_okay" = "yes" ]; then time1 ;
		elif [ "$date_okay" = "no" ] ; then time2 ; fi
	if [ "$overwrite" == "no" ]; then
  		if [ ! -f "$output/$film_ohne_ende-cut.avi" ]; then
			do_split_merge
  		else
	 		echo -e "${gelb}Die Ausgabedatei existiert bereits!${normal}"
	 		if [ $HaltByErrors == "yes" ]; then
				exit 1
	 		else
				continue=1
				 		fi
	  		fi
	   	fi
	   	if [ "$overwrite" == "yes" ]; then do_split_merge ; fi
   	fi
   	if [ "$CutProg" == "avidemux" ] || [ "$CutProg" == "avidemux2" ] || [ "$CutProg" == "avidemux2_cli" ] || [ "$CutProg" == "avidemux2_qt4" ] || [ "$CutProg" == "avidemux2_gtk" ] && [ $continue == "0" ]; then
		   	if [ "$overwrite" == "no" ]; then
			  	if [ ! -f "$output/$film_ohne_ende-cut.avi" ]; then
			 		demux
				else
			 		echo -e "${gelb}Die Ausgabedatei existiert bereits!${normal}"
			 		if [ $HaltByErrors == "yes" ]; then
							exit 1
			 		else
							continue=1
			 		fi
				fi
		   	fi
		   	if [ "$overwrite" == "yes" ]; then demux ; fi
   	fi
   	if [ "$UseLocalCutlist" == "no" ] && [ "$bewertung" == "yes" ] && [ "$continue" != "1" ]; then
   		if [ "$play" == "no"  ]; then bewerte_cutlist ; fi
   		if [ "$play" == "yes" ]; then
	  		echo "Starte nun den gewaehlten Videoplayer"
	  		$player "$outputfile"
	  		bewerte_cutlist
   		fi
   	fi
	if [ "$decoded" == "yes" ]; then rm -rf "$output/$film" ; fi
   	del_tmp
   	continue=0
done
### EOF ###
