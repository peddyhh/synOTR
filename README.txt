##############################################################################
#
# File  :   synOTR/README.txt
# Author:   peddy@gmx.net (Andreas Peters)
#			Orignal von: synotr@geimist.eu (Stephan Geisler)
# Date  :   28.04.2015
# Subj. :   Beschreibung zur Nutzung und zum Projekt
#
##############################################################################

Beschreibung:
synOTR ist ein scriptbasiterter Workflow fuer TV-Aufnahmen von onlineTVrecorder (OTR) auf einer Synology Diskstation (INTEL only), bzw. 
sollte jeder x86-Linuxrechner funktionieren. Es wurde gezielt auf Einfachheit hin entwickelt - wer einen Dateipfad in eine Textdatei 
eintragen kann, sollte hiermit zurecht kommen :-)

Folgende Aufgaben werden automatisch abgearbeitet:
	-	Verschluesselte .otrkey-Dateien dekodieren
	-	Filme schneiden (Quelle: cutlist.at) / das zugrunde liegende Script (OTRcut) stammt von Daniel Siegmanski (funktioniert 
		aufgrund der mitgelieferten Programme nicht fuer .mp4-Dateien)
	-	Filme nach eigenen Regeln umbenennen
		Serien werden automatisch erkannt und der Sendungsname umbenannt (Serientitel - S01E01_Episodentitel... )
		==> VIELEN DANK an Daniel von www.otr-serien.de fuer das zur Verfuegungstellen seiner Website.
		(Es wird 48h lang nach Serieninformationen gesucht, da diese nicht sofort auf otr-serien.de zur Verfuegung stehen. Schlaegt 
		die Suche dann immer noch fehl, so wird die Normale Umbenennung verwendet).
	-	Konvertieren der .avi Dateien in native .mp4 Dateien (Mac OS tauglich)

Laesst man sich fertige Aufnahmen per FTP-Push (z.B. Serien) auf die Diskstation uebertragen, hat man ohne Zutun fertig geschnittene Aufnahmen.

Das Script stuetzt sich in grossen Teilen auf Erkenntnisse in diesem Thread [klick]. Bitte entschuldigt den quick&dirty Code. Ohne Hilfe haette 
ich hier gar nichts geschafft. Mein Ziel war es, jetzt eine kompakte Loesung anbieten zu koennen, die fuer jedermann (vor allem auch Einsteiger) 
einfach nutzbar sein soll, ohne dass sich jeder in die Materie einarbeiten muss. Es ist also nichts an Skripten zu aendern, noch muessen 
zusaetzliche Programme installiert werden (es ist kein IPKG notwendig - wenn es so funktioniert, wie ich mir das vorstelle). Alle 
entsprechenden Programme sind in dem Paket enthalten. Derzeit wird zum schneiden avisplit/avimerge aus Transcode verwendet. Wie die Namen 
schon zeigen, sind sie auf .avi-Dateien beschraenkt. Die so erstellten Schnitte sind leider nicht framegenau (die Schnitte sind auf wenige 
Sekunden genau). Das beste (framegenaue) Ergebnis waere mit Hilfe von avidemux zu erreichen. Es waere super, wenn jemand dabei helfen koennte, 
avidemux-cli auf der DS zum laufen zu bringen. Entweder man koennte es mit den entsprechenden Abhaengigkeiten kompilieren oder gleich 
entsprechend installieren. Die Architektur ist ja kein Problem. Ich hoffe, dass alle mitgelieferten Programme out of the box funktionieren. 

Bitte unterstuetzt die Seite www.otr-serien.de. Ueber die Seite laesst es sich auch sehr einfach nach bestimmten Episoden suchen. Ihr habt 
eine ausgestrahlte Serienepisode, die dort nicht automatisch erkannt wurde? Dann gebt doch bei der betroffenen Episode eine Rueckmeldung ab.

! ! ! ACHTUNG ! ! ! 
DAS GANZE PAKET IST NOCH BETA. 
BENUTZUNG AUF EIGENE GEFAHR. 
BEI PROBLEMEN ODER FRAGEN BITTE DAS FORUM VERWENDEN. 

Verwendung / Vorbereitung:
	-	Lade das neuste Archiv auf deine Diskstation und entpacke es an deinem gewuenschten Zielort
	-	Oeffne die enthaltene Datei "Konfiguration.txt" mit einem Texteditor (z.B. der in DSM 5.1 enthaltene):
		Hier sind die OTR-Zugangsdaten fuer das Decodieren, den Ordner mit den .otrkey's sowie den Zielordner fuer die fertigen Filme einzutragen.
		Jeder der vier oben genannten Teilschritte kann aktiviert ("on"), oder deaktiviert ("off") werden. Desweiteren kann man sich ein Muster fuer den gewuenschten Zieldateinamen zusammenstellen. Jetzt noch die Datei abspeichern (unter Windows beim speichern auf UNIX-Zeilenenden achten!)
	-	Fuer den automatischen Ablauf ist das Script in den DSM-Aufgabenplaner einzutragen:
		- Kopiere den Pfad zum entpackten Ordner "synOTR" (Filestation > Rechtsklick > Eigenschaften)
		- Erstelle einen neuen Task im Aufgabenplaner (DSM-Systemsteuerung > Aufgabenplaner > Erstellen > Benutzer-definiertes Script) und fuege nachstehenden Code ein (ersetze den Pfad hinter "appdir=" mit deinem Pfad zum Ordner synOTR)
			Aufruf inkl. LOG (Pfad anpassen ! ! ! ):
				appdir=/volume1/homes/admin/script/synOTR/ && cd $appdir && ./synOTR-start.sh >> ./_LOG/synOTR_$(date '+%Y-%m-%d_%H-%M').log 2>&1
			oder nur direkter Aufruf des Skripts (Pfad anpassen ! ! ! - dann ohne LOG):
				/volume1/homes/admin/script/synOTR/synOTR-start.sh
			erstelle einen gewuenschten Zeitplan (z.B. stuendlich)
			(Die Logfiles sind ziemlich gross - z.T. ueber 50 MB. Sie befinden sich im Unterordner "_LOG" und koennen jederzeit geloescht werden. Laeuft alles reibungslos, dann empfiehlt es sich wahrscheinlich im Aufgabenplaner den Scriptaufruf ohne Logfile zu verwenden)



Download:
https://geimist.eu/synOTR/

ToDo:
	-	Metatags fuer die Serieninformationen in die .mp4 Dateien setzen (AtomicParsley o.ae.)
	-	avidemux-cli als Schnittprogramm verwenden (hat jemand Hilfe ...) 
	-	es ist mir noch nicht gelungen, fuer die AAC-Konvertierung in ffmpeg Multihreading zu aktivieren. Alle neuen DSen mit Intel-CPU's haben ja 4 Threads bzw. 4 Kerne. Koennte man mehrere parallel nutzen, ginge das Ganze natuerlich noch etwas flotter.
	-	ganz toll waere es auch, wenn jemand eine PHP-Seite / GUI fuer die Konfigurationsdatei schreiben koennte. So liesse sich das Ganze auch bequem per SPK installieren und verwalten. Des Weiteren waere so auch eine manuelle Cutlist-Auswahl moeglich. 

getestete Modelle:
	-	DS713+ (DSM 5.1)
	-	

LIZENZ:
Dieses Script darf frei veraendert und weitergegeben werden. 
Das Script "OTRcut" sowie die enthaltenen Programme stehen unter deren eigenen Lizenz.

### EOF ###
